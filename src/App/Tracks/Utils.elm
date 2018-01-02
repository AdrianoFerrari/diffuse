module Tracks.Utils exposing (..)

import Dom.Scroll
import Task
import Tracks.Types exposing (..)
import Types as TopLevel exposing (Illumination)
import Utils


-- 🔥


($) : Illumination Model Msg
($) =
    Utils.illuminate TopLevel.TracksMsg



-- 🌱


getIdentifiers : IdentifiedTrack -> Identifiers
getIdentifiers =
    Tuple.first


identifiedId : IdentifiedTrack -> TrackId
identifiedId =
    unindentify >> .id


unindentify : IdentifiedTrack -> Track
unindentify =
    Tuple.second



-- Now playing


isNowPlaying : IdentifiedTrack -> IdentifiedTrack -> Bool
isNowPlaying ( a, b ) ( x, y ) =
    a.indexInPlaylist == x.indexInPlaylist && b == y
