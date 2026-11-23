class_name UkuleleSynth
extends AudioStreamPlayer
## A small plucked-string synthesizer (Karplus-Strong): each note starts as a burst of
## soft noise in a loop as long as one wave of the note, and every pass through the loop
## averages and fades it, which turns the noise into a warm, quickly fading pluck.
## Original sound made entirely in code, no recordings.

const MIX_RATE := 22050.0
const MAX_VOICES := 6
## How quickly a note fades (closer to 1 = longer ring). Ukuleles ring short.
const DECAY := 0.9955
const VOICE_SECONDS := 1.8
const VOLUME := 0.38

## One ringing string.
class Voice:
	var buffer: PackedFloat32Array
	var index: int = 0
	var samples_left: int = 0
	var gain: float = 1.0

var _voices: Array[Voice] = []
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
## Notes started so far (for tests and the HUD).
var notes_played: int = 0


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.12
	stream = generator
	volume_db = -4.0
	bus = &"Music"  # the Music volume slider (falls back to Master if the bus is missing)
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


## Plucks a note at this frequency (Hz).
func pluck(frequency: float, strength: float = 1.0) -> void:
	notes_played += 1
	var length := maxi(int(round(MIX_RATE / maxf(frequency, 40.0))), 2)
	var voice := Voice.new()
	voice.buffer = PackedFloat32Array()
	voice.buffer.resize(length)
	# Soft, slightly low-passed noise: a gentle fingertip pluck rather than a pick.
	var previous := 0.0
	for i in length:
		var noise := _rng.randf_range(-1.0, 1.0)
		previous = previous * 0.45 + noise * 0.55
		voice.buffer[i] = previous
	voice.samples_left = int(MIX_RATE * VOICE_SECONDS)
	voice.gain = clampf(strength, 0.1, 1.0) * VOLUME
	_voices.append(voice)
	if _voices.size() > MAX_VOICES:
		_voices.pop_front()


func get_active_voices() -> int:
	return _voices.size()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		_age_voices(int(MIX_RATE * _delta))
		return
	var out := PackedVector2Array()
	out.resize(frames)
	for f in frames:
		var sample := 0.0
		for voice in _voices:
			var length := voice.buffer.size()
			var i := voice.index
			var current := voice.buffer[i]
			var next := voice.buffer[(i + 1) % length]
			voice.buffer[i] = (current + next) * 0.5 * DECAY
			voice.index = (i + 1) % length
			sample += current * voice.gain
			voice.samples_left -= 1
		sample = clampf(sample, -1.0, 1.0)
		out[f] = Vector2(sample, sample)
	_playback.push_buffer(out)
	_drop_finished()


## Without an audio device (headless tests) nothing is pulled, so notes still age.
func _age_voices(samples: int) -> void:
	for voice in _voices:
		voice.samples_left -= samples
	_drop_finished()


func _drop_finished() -> void:
	for i in range(_voices.size() - 1, -1, -1):
		if _voices[i].samples_left <= 0:
			_voices.remove_at(i)
