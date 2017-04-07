module Tracks.View exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onDoubleClick)
import Maybe.Extra as Maybe
import Navigation.View as Navigation
import Queue.Types as Queue
import Queue.Utils exposing (makeQueueItem)
import Styles exposing (Classes(Button, ContentBox))
import Types exposing (Model, Msg(..))
import Utils exposing (cssClass)


-- 🍯


entry : Model -> Html Msg
entry model =
    ul
        []
        (List.map
            (\track ->
                li
                    [ track
                        |> makeQueueItem model
                        |> Queue.InjectFirstAndPlay
                        |> QueueMsg
                        |> onDoubleClick
                    ]
                    ([ track.tags.artist
                     , track.tags.title
                     ]
                        |> List.filter (Maybe.isJust)
                        |> List.map (Maybe.withDefault "")
                        |> String.join " – "
                        |> text
                        |> List.singleton
                    )
            )
            model.queue.tracks
        )
