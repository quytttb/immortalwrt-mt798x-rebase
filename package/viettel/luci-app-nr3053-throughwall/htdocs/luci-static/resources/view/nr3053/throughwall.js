'use strict';
'require view';
'require form';
'require uci';
'require rpc';
'require ui';
'require fs';

const callInitAction = rpc.declare({
	object: 'luci',
	method: 'setInitAction',
	params: ['name', 'action'],
	expect: { result: false }
});

return view.extend({
	load: function() {
		return uci.load('throughwall');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('throughwall', _('WiFi Xuyên Tường (ThroughWall)'),
			_('Tính năng khôi phục công suất phát WiFi 5GHz về mức tối đa cho NR3053. ' +
			  'ROM gốc Viettel giới hạn công suất này khiến sóng yếu. ' +
			  'Sau khi bật, tốc độ xuyên tường sẽ ngang bằng 32X6. ' +
			  '<br><br>' +
			  '<strong>Lưu ý:</strong> Hiệu lực ngay lập tức, không cần khởi động lại. ' +
			  'Cài đặt được lưu và tự áp dụng sau mỗi lần khởi động.')
		);

		s = m.section(form.NamedSection, 'throughwall', 'throughwall');
		s.anonymous = true;

		// Toggle bật/tắt chính
		o = s.option(form.Flag, 'enable', _('Bật chế độ Xuyên Tường'),
			_('Ghi đè giá trị calibration EEPROM (offset 0x81e-0x87e) sang 0xC4C4 để tối ưu TX power 5GHz.')
		);
		o.default = '1';
		o.rmempty = false;

		// Thêm nút "Áp dụng ngay" (không cần chờ reboot)
		o = s.option(form.Button, '_apply', _('Áp dụng Ngay'));
		o.inputstyle = 'apply';
		o.inputtitle = _('Áp dụng không cần reboot');
		o.onclick = function(ev) {
			var enable = uci.get('throughwall', 'throughwall', 'enable');
			return m.save().then(function() {
				return fs.exec('/etc/init.d/viettel-nr3053-throughwall', ['start']);
			}).then(function() {
				ui.addNotification(null,
					E('p', enable === '1'
						? _('✅ Đã bật xuyên tường. WiFi 5GHz đang hoạt động ở công suất tối đa!')
						: _('⚠️ Đã tắt xuyên tường. Giá trị gốc sẽ được khôi phục sau khi khởi động lại.')
					), 'info'
				);
			}).catch(function(err) {
				ui.addNotification(null,
					E('p', _('Lỗi: ') + err.message), 'danger'
				);
			});
		};

		// Thông tin trạng thái
		s.option(form.DummyValue, '_info',
			_('<strong>Thông tin kỹ thuật</strong>')
		).rawhtml = true;

		var info = s.option(form.DummyValue, '_detail', ' ');
		info.rawhtml = true;
		info.cfgvalue = function() {
			return '<div style="background:#f8f8f8;border:1px solid #ddd;padding:10px;border-radius:4px;font-size:0.9em">' +
				'<p>🔧 <strong>Thiết bị áp dụng:</strong> Viettel NR3053</p>' +
				'<p>📡 <strong>Dải tần:</strong> 5GHz (<code>rax0</code>)</p>' +
				'<p>📍 <strong>Vùng EEPROM:</strong> Offset 0x81E – 0x87E (55 offset)</p>' +
				'<p>📊 <strong>Giá trị boost:</strong> <code>0xC4C4</code></p>' +
				'<p>💾 <strong>Phương thức:</strong> Ghi vào RAM qua <code>iwpriv</code>, an toàn cho NAND flash</p>' +
				'<p>🔄 <strong>Tự động:</strong> Áp dụng mỗi lần khởi động qua hotplug</p>' +
				'<p>📈 <strong>Kết quả thực tế:</strong> ~300 Mbps xuyên 1 tầng (vs 32X6: ~240 Mbps)</p>' +
				'</div>';
		};

		return m.render();
	},

	handleSaveApply: function(ev) {
		return this.handleSave(ev).then(function() {
			return fs.exec('/etc/init.d/viettel-nr3053-throughwall', ['start']);
		}).then(function() {
			ui.addNotification(null,
				E('p', _('✅ Đã lưu và áp dụng ngay!')), 'info'
			);
		});
	}
});
