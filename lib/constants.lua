local NONE = 'none'
local OCTAVE = 'octave'
local MUTE = 'mute'
local RESET_SELF = 'reset self'
local RESET_OTHER = 'reset other'
local RESET_ALL = 'reset all'

local AUDIO = 'audio'
local MIDI = 'midi'
local AUDIO_MIDI = 'audio + midi'
local CROW_II_JF = 'crow ii jf'

local constants = {
  GRID_HEIGHT = 8,
  GRID_LENGTH = 15,
  GRID_NAV_COL = 16,
  LFO_NUM = 4,
  GRID_LEVELS = {DIM = 2, LOW_MED = 4, MED = 8, HIGH = 14 },
  INTERSECT_OP_NONE = NONE,
  INTERSECT_OP_OCTAVE = OCTAVE,
  INTERSECT_OP_MUTE = MUTE,
  INTERSECT_OP_RESET_SELF = RESET_SELF,
  INTERSECT_OP_RESET_OTHER = RESET_OTHER,
  INTERSECT_OP_RESET_ALL = RESET_ALL,
  INTERSECT_OPS = {NONE, OCTAVE, MUTE, RESET_SELF, RESET_OTHER, RESET_ALL}
  OUTPUTS = {AUDIO, MIDI, AUDIO_MIDI, CROW_II_JF}
}

return constants
