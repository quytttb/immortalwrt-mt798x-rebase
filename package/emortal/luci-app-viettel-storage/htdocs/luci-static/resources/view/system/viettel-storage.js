'use strict';
'require view';
'require fs';
'require ui';

function parseStatus(output) {
	const status = {};

	String(output || '').trim().split(/\n/).forEach(function(line) {
		const separator = line.indexOf('=');
		if (separator > 0)
			status[line.slice(0, separator)] = line.slice(separator + 1);
	});

	return status;
}

function formatKiB(value) {
	const kib = Number(value || 0);

	if (!kib)
		return '-';
	if (kib >= 1024 * 1024)
		return '%.1f GiB'.format(kib / 1024 / 1024);
	if (kib >= 1024)
		return '%.1f MiB'.format(kib / 1024);
	return '%d KiB'.format(kib);
}

function detailRow(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td', 'style': 'width:35%' }, E('strong', label)),
		E('td', { 'class': 'td' }, value)
	]);
}

return view.extend({
	load() {
		return fs.exec_direct('/usr/sbin/viettel-storage', [ 'status' ]).then(parseStatus);
	},

	handlePrepare(mode) {
		const title = mode === 'overlay' ?
			_('Dùng storage để mở rộng overlay') :
			_('Khôi phục storage riêng');
		const explanation = mode === 'overlay' ?
			_('Thao tác này sẽ xóa toàn bộ dữ liệu trong /mnt/storage ở lần sysupgrade sạch kế tiếp và cấp phần dung lượng đó cho overlay. Sau khi hoàn tất, mọi gói APK mới sẽ dùng overlay lớn hơn.') :
			_('Thao tác này sẽ xóa overlay ở lần sysupgrade sạch kế tiếp, tạo lại storage riêng tại /mnt/storage và giới hạn overlay theo layout mặc định.');

		ui.showModal(title, [
			E('p', explanation),
			E('p', E('strong', _('Sau khi xác nhận, hãy flash đúng file sysupgrade và bỏ chọn “Giữ lại cấu hình”. Router sẽ khởi động lại với layout mới.'))),
			E('div', { 'class': 'right' }, [
				E('button', {
					'class': 'btn',
					'click': ui.hideModal
				}, _('Hủy')), ' ',
				E('button', {
					'class': 'btn cbi-button-negative',
					'click': ui.createHandlerFn(this, function() {
						return fs.exec('/usr/sbin/viettel-storage', [ 'prepare-' + mode ]).then(function(result) {
							if (result.code !== 0)
								throw new Error(result.stderr || result.stdout || _('Không thể chuẩn bị chuyển layout.'));

							ui.hideModal();
							ui.addNotification(null, E('p', _('Đã ghi lựa chọn. Hãy chạy sysupgrade sạch bằng đúng firmware cho NR3053 để áp dụng.')), 'info');
						}).catch(function(error) {
							ui.addNotification(null, E('p', error.message));
						});
					})
				}, _('Xác nhận'))
			])
		]);
	},

	render(status) {
		const hasStorage = !!status.storage_volume;
		const isOverlayMode = status.mode === 'overlay';
		const storageState = isOverlayMode ?
			_('Đã gộp vào overlay sau sysupgrade') :
			(status.storage_mounted === '1' ? _('Đã mount tại /mnt/storage') :
				(hasStorage ? _('Có volume nhưng chưa mount') : _('Chưa có volume storage')));
		const actionLabel = isOverlayMode ?
			_('Khôi phục storage riêng ở sysupgrade kế tiếp') :
			_('Dùng storage để mở rộng overlay ở sysupgrade kế tiếp');
		const actionMode = isOverlayMode ? 'storage' : 'overlay';

		return E([], [
			E('h2', _('Lưu trữ nội bộ')),
			E('div', { 'class': 'cbi-map-descr' },
				_('NR3053 có một volume UBI dành riêng cho dữ liệu. Mặc định volume này được mount tự động tại /mnt/storage để lưu tải xuống, cơ sở dữ liệu và backup; APK vẫn cài vào overlay.')),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', _('Trạng thái')),
				E('table', { 'class': 'table' }, [
					detailRow(_('Chế độ'), isOverlayMode ? _('Overlay mở rộng') : _('Storage riêng')),
					detailRow(_('Storage'), storageState),
					detailRow(_('Dung lượng storage'), formatKiB(status.storage_total_kib)),
					detailRow(_('Còn trống storage'), formatKiB(status.storage_available_kib)),
					detailRow(_('Dung lượng overlay'), formatKiB(status.overlay_total_kib)),
					detailRow(_('Còn trống overlay'), formatKiB(status.overlay_available_kib))
				])
			]),
			E('div', { 'class': 'cbi-section' }, [
				E('h3', _('Thay đổi cách dùng dung lượng')),
				E('p', isOverlayMode ?
					_('Khôi phục storage riêng sẽ làm sạch overlay để tạo lại hai vùng riêng biệt.') :
					_('Chuyển sang overlay mở rộng sẽ xóa storage riêng, rồi cấp phần dung lượng đó cho nơi cài ứng dụng sau một lần sysupgrade sạch.')),
				E('button', {
					'class': 'btn cbi-button-negative',
					'disabled': !hasStorage && !isOverlayMode,
					'click': ui.createHandlerFn(this, 'handlePrepare', actionMode)
				}, actionLabel)
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
