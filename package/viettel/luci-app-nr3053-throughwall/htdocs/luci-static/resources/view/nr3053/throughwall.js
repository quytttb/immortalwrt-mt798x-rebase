'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require ui';

// Chạy init.d action qua luci ubus (chuẩn LuCI)
const callInitAction = rpc.declare({
	object: 'luci',
	method: 'setInitAction',
	params: ['name', 'action'],
	expect: { result: false }
});

// Đọc EEPROM qua wrapper script (whitelisted trong ACL)
// /usr/bin/throughwall-eeprom-read chạy: iwpriv rax0 e2p 81e
const callExecEepromRead = rpc.declare({
	object: 'file',
	method: 'exec',
	params: ['command'],
	expect: { stdout: '' }
});

// Reboot router
const callReboot = rpc.declare({
	object: 'system',
	method: 'reboot',
	expect: {}
});

return view.extend({

	load: function() {
		return Promise.all([
			uci.load('throughwall'),
			callExecEepromRead('/usr/bin/throughwall-eeprom-read')
				.catch(function() { return { stdout: '' }; })
		]);
	},

	_parseEeprom: function(stdout) {
		var m = (stdout || '').match(/\[0x[0-9A-Fa-f]+\]:(0x[0-9A-Fa-f]+)/i);
		return m ? m[1].toUpperCase() : null;
	},

	_renderStatus: function(uciEnable, eepromVal) {
		var label, cssClass;

		if (eepromVal === null) {
			cssClass = 'label-warning';
			label = _('⚠ Không đọc được EEPROM — rax0 chưa sẵn sàng hoặc driver lỗi');
		} else if (eepromVal === '0XC4C4') {
			cssClass = 'label-success';
			label = _('✔ Đang hoạt động — EEPROM = 0xC4C4');
		} else if (uciEnable === '1') {
			cssClass = 'label-warning';
			label = _('⚠ UCI bật nhưng chưa áp dụng — EEPROM = ') + eepromVal + _('. Nhấn "Lưu & áp dụng".');
		} else {
			cssClass = 'label-default';
			label = _('✘ Đã tắt — EEPROM = ') + eepromVal;
		}

		return E('div', { 'class': 'cbi-value' }, [
			E('label', { 'class': 'cbi-value-title' }, _('Trạng thái')),
			E('div', { 'class': 'cbi-value-field' }, [
				E('span', { 'class': 'label ' + cssClass }, label)
			])
		]);
	},

	render: function(data) {
		var eepromVal = this._parseEeprom(data[1] != null ? data[1] : '');
		var uciEnable = uci.get('throughwall', 'throughwall', 'enable') || '0';

		var m, s, o;

		m = new form.Map('throughwall',
			_('WiFi Xuyên Tường (ThroughWall)'),
			_('Khôi phục công suất phát WiFi 5GHz về mức tối đa cho NR3053. ' +
			  'ROM gốc Viettel giới hạn công suất radio khiến sóng yếu khi xuyên tường. ' +
			  'Cài đặt được lưu và tự áp dụng sau mỗi lần khởi động.')
		);

		// Lưu map để các handler truy cập được
		this._map = m;

		s = m.section(form.NamedSection, 'throughwall', 'throughwall');
		s.anonymous = true;
		s.addremove = false;

		// Toggle bật/tắt
		o = s.option(form.Flag, 'enable',
			_('Bật chế độ Xuyên Tường'),
			_('Ghi đè calibration EEPROM (55 offset, 0x81E–0x87E) sang 0xC4C4 để tối ưu TX power 5GHz.')
		);
		o.default = '1';
		o.rmempty = false;

		return m.render().then(L.bind(function(node) {
			// Thêm khối trạng thái vào cuối fieldset section
			var fieldset = node.querySelector('fieldset.cbi-section');
			var statusBlock = this._renderStatus(uciEnable, eepromVal);
			if (fieldset) {
				fieldset.appendChild(statusBlock);
			} else {
				node.appendChild(statusBlock);
			}
			return node;
		}, this));
	},

	// Tạo footer với 2 nút tùy chỉnh thay vì nút mặc định
	addFooter: function() {
		return E('div', { 'class': 'cbi-page-actions' }, [
			E('button', {
				'class': 'btn cbi-button cbi-button-apply',
				'click': L.bind(this.handleSaveApply, this)
			}, _('Lưu & áp dụng')),
			E('button', {
				'class': 'btn cbi-button cbi-button-action',
				'style': 'margin-left:0.5em',
				'click': L.bind(this.handleSaveRestart, this)
			}, _('Lưu & Khởi động lại'))
		]);
	},

	// Lưu UCI + chạy init.d start (áp dụng iwpriv ngay, không reboot)
	handleSaveApply: function(ev) {
		return this._map.save().then(function() {
			return uci.apply();
		}).then(function() {
			return callInitAction('viettel-nr3053-throughwall', 'start');
		}).then(function() {
			ui.addNotification(null,
				E('p', _('✔ Đã lưu và áp dụng thành công. Đang tải lại trang...')),
				'info'
			);
			window.setTimeout(function() { location.reload(); }, 1500);
		}).catch(function(err) {
			ui.addNotification(null,
				E('p', _('✘ Lỗi: ') + (err.message || String(err))),
				'danger'
			);
		});
	},

	// Lưu UCI + reboot router
	handleSaveRestart: function(ev) {
		return this._map.save().then(function() {
			return uci.apply();
		}).then(function() {
			ui.showModal(_('Đang khởi động lại...'), [
				E('p', { 'class': 'spinning' },
					_('Router đang khởi động lại. Trang sẽ tự tải lại sau ~30 giây.')
				)
			]);
			return callReboot();
		}).then(function() {
			window.setTimeout(function() { location.reload(); }, 30000);
		}).catch(function(err) {
			ui.hideModal();
			ui.addNotification(null,
				E('p', _('✘ Lỗi khởi động lại: ') + (err.message || String(err))),
				'danger'
			);
		});
	},

	// Tắt các handler mặc định không dùng
	handleSave: null,
	handleReset: null
});
