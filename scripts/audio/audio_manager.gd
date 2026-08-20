extends Node

# Simple audio manager. Uses procedural beeps so no external audio files are needed.
# Every sound is a short synthesized tone via AudioStreamGenerator, or a simple
# AudioStreamWAV generated at runtime.

var _player: AudioStreamPlayer
var _sound_enabled: bool = true

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_load_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		_sound_enabled = bool(cfg.get_value("Settings", "sound_enabled", true))

func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled
	if not enabled:
		_player.stop()

func is_sound_enabled() -> bool:
	return _sound_enabled

# Play a simple tone by generating an AudioStreamWAV at runtime.
func play_tone(freq: float, duration: float = 0.12, volume_db: float = -8.0) -> void:
	if not _sound_enabled:
		return
	var stream := _make_tone_stream(freq, duration)
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()

# Tiny helper that packs a sine wave into an AudioStreamWAV.
func _make_tone_stream(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono

	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		# Fade out to avoid clicks
		var env := 1.0 - float(i) / float(sample_count)
		var sample := sin(TAU * freq * t) * env * 0.4
		var int_sample := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

# --- Game sounds -------------------------------------------------------------------

func play_click() -> void:
	play_tone(880.0, 0.06, -10.0)

func play_shape_drawn() -> void:
	play_tone(660.0, 0.08, -8.0)

func play_shape_committed() -> void:
	play_tone(520.0, 0.10, -6.0)
	# Second harmonic for a richer commit
	var t := Timer.new()
	t.wait_time = 0.05
	t.one_shot = true
	add_child(t)
	t.timeout.connect(func():
		play_tone(880.0, 0.08, -10.0)
		t.queue_free())

func play_skip() -> void:
	play_tone(340.0, 0.07, -8.0)

func play_erase() -> void:
	play_tone(450.0, 0.06, -10.0)

func play_stage_clear() -> void:
	play_tone(700.0, 0.12, -6.0)
	var t1 := Timer.new()
	t1.wait_time = 0.12
	t1.one_shot = true
	add_child(t1)
	t1.timeout.connect(func():
		play_tone(1050.0, 0.15, -6.0)
		t1.queue_free())

func play_victory() -> void:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in range(notes.size()):
		var timer := Timer.new()
		timer.wait_time = 0.12 * i
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(func():
			play_tone(notes[i], 0.16, -4.0)
			timer.queue_free())

func play_error() -> void:
	play_tone(220.0, 0.12, -4.0)

func play_hint() -> void:
	play_tone(1200.0, 0.09, -8.0)

func play_timer_tick() -> void:
	play_tone(1000.0, 0.03, -14.0)

func play_timer_expired() -> void:
	play_tone(200.0, 0.2, -4.0)

func play_menu_open() -> void:
	play_tone(600.0, 0.1, -8.0)

func play_mode_select() -> void:
	play_tone(750.0, 0.1, -6.0)
