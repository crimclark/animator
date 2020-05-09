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
local CROW_II_SC = 'ER-301'
local CROW_II_TXO = 'TXo'
local CROW_CV = 'crow cv'
local CROW_CV_JF = 'crow cv + JF'
local AUDIO_CV_JF = 'audio + cv + JF'
local GRID_LENGTH = 16
local GRID_HEIGHT = 8

local constants = {
  GRID_HEIGHT = GRID_HEIGHT,
  GRID_LENGTH = GRID_LENGTH,
  CANVAS_HEIGHT = GRID_HEIGHT - 1,
  CANVAS_LENGTH = GRID_LENGTH,
  GRID_NAV_ROW = 8,
  LFO_NUM = 2,
  GRID_LEVELS = {DIM = 2, LOW_MED = 5, MED = 9, HIGH = 15},
  INTERSECT_OP_NONE = NONE,
  INTERSECT_OP_OCTAVE = OCTAVE,
  INTERSECT_OP_MUTE = MUTE,
  INTERSECT_OP_RESET_SELF = RESET_SELF,
  INTERSECT_OP_RESET_OTHER = RESET_OTHER,
  INTERSECT_OP_RESET_ALL = RESET_ALL,
  INTERSECT_OPS = {NONE, OCTAVE, MUTE, RESET_SELF, RESET_OTHER, RESET_ALL},
  OUTPUT_AUDIO = AUDIO,
  OUTPUT_MIDI = MIDI,
  OUTPUT_AUDIO_MIDI = AUDIO_MIDI,
  OUTPUT_CROW_II_JF = CROW_II_JF,
  OUTPUT_CROW_CV = CROW_CV,
  OUTPUT_CROW_CV_JF = CROW_CV_JF,
  OUTPUT_AUDIO_CV_JF = AUDIO_CV_JF,
  OUTPUT_CROW_II_SC = CROW_II_SC,
  OUTPUT_CROW_II_TXO = CROW_II_TXO,
  OUTPUTS = {AUDIO, MIDI, AUDIO_MIDI, CROW_II_JF, CROW_CV, CROW_CV_JF, AUDIO_CV_JF, CROW_II_SC, CROW_II_TXO},
  EVENT_PATTERN = 'pattern',
  EVENT_SNAPSHOT = 'snapshot'
}

return constants
