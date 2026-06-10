/*
 * Keenetic bndstrg talks to mt_wifi via RT_PRIV_IOCTL. The daemon uses syscall()
 * directly (not libc ioctl), so LD_PRELOAD must hook syscall as well as ioctl.
 *
 * Driver→daemon responses must not be forwarded into the kernel. INF_STATUS_RSP
 * and CHANLOAD_STATUS_RSP are synthesized in userspace when the driver does not
 * return them via the ioctl buffer (kernel 6.12 + mt_wifi).
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdarg.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <linux/wireless.h>
#include <unistd.h>

#define RT_PRIV_IOCTL		(SIOCIWFIRSTPRIV + 0x01)
#define OID_BNDSTRG_MSG		0x0950

#define CLI_EVENT		1
#define CLI_STATUS_RSP		5
#define CHANLOAD_STATUS_REQ	6
#define CHANLOAD_STATUS_RSP	7
#define INF_STATUS_QUERY	8
#define INF_STATUS_RSP		9
#define TABLE_INFO		10
#define ENTRY_LIST		11
#define REJECT_EVENT		15

typedef struct {
	unsigned int Action;
	union {
		char ucIfName[32];
		struct {
			unsigned char bInfReady;
			unsigned char Idx;
			unsigned char Channel;
			unsigned char bVHTCapable;
			unsigned long table_src_addr;
			char rsp_ifname[32];
			unsigned char nvram_support;
			unsigned char nss;
			unsigned char band;
			unsigned int table_size;
		} inf_rsp;
		struct {
			unsigned char ReturnCode;
			unsigned char band;
			unsigned char Channel;
			unsigned char chanload;
			unsigned char chan_busy_load;
			unsigned char obss_load;
			unsigned char edcca_load;
			unsigned char myair_load;
			unsigned char mytxair_load;
			unsigned char myrxair_load;
		} chanload_rsp;
	} data;
} bndstrg_msg_t;

static int wifi_sock = -1;
static int (*real_ioctl)(int, int, ...) = NULL;
static long (*real_syscall)(long, ...) = NULL;

static int wifi_socket(void)
{
	if (wifi_sock < 0)
		wifi_sock = socket(AF_INET, SOCK_DGRAM, 0);
	return wifi_sock;
}

static int is_5g_if(const char *ifname)
{
	return ifname[0] == 'r' && ifname[1] == 'a' && ifname[2] == 'x';
}

static int is_driver_to_daemon_action(unsigned int action)
{
	switch (action) {
	case CLI_EVENT:
	case CLI_STATUS_RSP:
	case CHANLOAD_STATUS_RSP:
	case INF_STATUS_RSP:
	case TABLE_INFO:
	case ENTRY_LIST:
	case REJECT_EVENT:
		return 1;
	default:
		return 0;
	}
}

static void fill_inf_status_rsp(bndstrg_msg_t *msg, const char *ifname)
{
	memset(&msg->data, 0, sizeof(msg->data));
	msg->Action = INF_STATUS_RSP;
	msg->data.inf_rsp.bInfReady = 1;
	msg->data.inf_rsp.band = is_5g_if(ifname) ? 1 : 0;
	strncpy(msg->data.inf_rsp.rsp_ifname, ifname,
		sizeof(msg->data.inf_rsp.rsp_ifname) - 1);
}

static void fill_chanload_status_rsp(bndstrg_msg_t *msg, const char *ifname)
{
	memset(&msg->data, 0, sizeof(msg->data));
	msg->Action = CHANLOAD_STATUS_RSP;
	msg->data.chanload_rsp.ReturnCode = 0;
	msg->data.chanload_rsp.band = is_5g_if(ifname) ? 1 : 0;
}

static int bndstrg_ioctl(struct iwreq *wrq, bndstrg_msg_t *msg)
{
	const char *prefer = (msg && msg->data.ucIfName[0]) ? msg->data.ucIfName : NULL;
	const char *fallback = "rax0";
	int ret = -1;

	if (msg && is_driver_to_daemon_action(msg->Action))
		return 0;

	strncpy(wrq->ifr_name, prefer ? prefer : "ra0", IFNAMSIZ - 1);
	wrq->ifr_name[IFNAMSIZ - 1] = '\0';
	ret = real_ioctl(wifi_socket(), RT_PRIV_IOCTL, wrq);

	if (ret < 0 && !prefer) {
		strncpy(wrq->ifr_name, fallback, IFNAMSIZ - 1);
		ret = real_ioctl(wifi_socket(), RT_PRIV_IOCTL, wrq);
	}

	if (ret == 0 && msg) {
		if (msg->Action == INF_STATUS_QUERY)
			fill_inf_status_rsp(msg, wrq->ifr_name);
		else if (msg->Action == CHANLOAD_STATUS_REQ)
			fill_chanload_status_rsp(msg, wrq->ifr_name);
	}

	return ret;
}

static int handle_bndstrg_ioctl(void *arg)
{
	struct iwreq *wrq = arg;
	bndstrg_msg_t *msg;

	if (!wrq || wrq->u.data.flags != OID_BNDSTRG_MSG)
		return -1;

	msg = wrq->u.data.pointer ? (bndstrg_msg_t *)wrq->u.data.pointer : NULL;
	return bndstrg_ioctl(wrq, msg);
}

int ioctl(int fd, int request, ...)
{
	void *arg;
	va_list ap;
	int ret;

	if (!real_ioctl)
		real_ioctl = dlsym(RTLD_NEXT, "ioctl");

	va_start(ap, request);
	arg = va_arg(ap, void *);
	va_end(ap);

	if (request != RT_PRIV_IOCTL)
		return real_ioctl(fd, request, arg);

	ret = handle_bndstrg_ioctl(arg);
	if (ret >= 0)
		return ret;

	return real_ioctl(fd, request, arg);
}

long syscall(long number, ...)
{
	long a0, a1, a2, a3, a4, a5;
	va_list ap;

	if (!real_syscall)
		real_syscall = dlsym(RTLD_NEXT, "syscall");

	va_start(ap, number);
	a0 = va_arg(ap, long);
	a1 = va_arg(ap, long);
	a2 = va_arg(ap, long);
	a3 = va_arg(ap, long);
	a4 = va_arg(ap, long);
	a5 = va_arg(ap, long);
	va_end(ap);

	if (number == __NR_ioctl && (int)a1 == RT_PRIV_IOCTL) {
		int ret = handle_bndstrg_ioctl((void *)a2);

		if (ret >= 0)
			return ret;
	}

	return real_syscall(number, a0, a1, a2, a3, a4, a5);
}
