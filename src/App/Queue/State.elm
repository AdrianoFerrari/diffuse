module Queue.State exposing (..)

import Date exposing (Date)
import DnD
import List.Extra as List
import List.Ext as List
import Notifications.Types as Notification
import Response.Ext exposing (do)
import Queue.Fill as Fill
import Queue.Ports as Ports
import Queue.Types exposing (..)
import Queue.Utils exposing (..)
import String.Interpolate exposing (interpolate)
import Tracks.Types exposing (IdentifiedTrack)
import Tracks.Utils
import Types as TopLevel


-- 💧


initialModel : Model
initialModel =
    { activeItem = Nothing
    , future = []
    , past = []
    , ignored = []

    -- Settings
    , repeat = False
    , shuffle = False

    -- UI
    , itemDnD = DnD.initial
    }



-- 🔥


update : Msg -> Model -> ( Model, Cmd TopLevel.Msg )
update msg model =
    case msg of
        -- # InjectFirst
        -- > Add an item in front of the queue.
        --
        InjectFirst identifiedTrack options ->
            let
                item =
                    { manualEntry = True
                    , identifiedTrack = identifiedTrack
                    }

                track =
                    Tracks.Utils.unindentify identifiedTrack

                cleanedFuture =
                    Fill.cleanAutoGenerated model.shuffle track.id model.future
            in
                (!)
                    { model
                        | future = item :: cleanedFuture
                    }
                    [ do TopLevel.FillQueue

                    -- Notification (if requested)
                    , if options.showNotification then
                        [ track.tags.title ]
                            |> interpolate "**{0}** will be played next"
                            |> Notification.Message
                            |> TopLevel.ShowNotification
                            |> do
                      else
                        Cmd.none
                    ]

        -- # InjectLast
        -- > Add an item after the last manual entry
        --   (ie. after the last injected item).
        --
        InjectLast identifiedTracks options ->
            let
                items =
                    List.map (makeItem True) identifiedTracks

                tracks =
                    List.map Tracks.Utils.unindentify identifiedTracks

                cleanedFuture =
                    List.foldl
                        (\track future ->
                            Fill.cleanAutoGenerated model.shuffle track.id future
                        )
                        model.future
                        tracks

                manualItems =
                    cleanedFuture
                        |> List.filter (.manualEntry >> (==) True)
                        |> List.length
            in
                (!)
                    { model
                        | future =
                            []
                                ++ List.take manualItems cleanedFuture
                                ++ items
                                ++ List.drop manualItems cleanedFuture
                    }
                    [ do TopLevel.FillQueue

                    -- Notification (if requested)
                    , if options.showNotification && List.length items == 1 then
                        tracks
                            |> List.head
                            |> Maybe.withDefault Tracks.Types.emptyTrack
                            |> (\track -> track.tags.title)
                            |> List.singleton
                            |> interpolate "**{0}** was added to the queue"
                            |> Notification.Message
                            |> TopLevel.ShowNotification
                            |> do
                      else
                        Cmd.none
                    ]

        -- # RemoveItem Int
        -- > Remove an item from the queue.
        --
        RemoveItem index ->
            let
                maybeItem =
                    List.getAt index model.future

                newFuture =
                    List.removeAt index model.future

                newIgnored =
                    case maybeItem of
                        Just item ->
                            if item.manualEntry then
                                model.ignored
                            else
                                item :: model.ignored

                        Nothing ->
                            model.ignored
            in
                (!)
                    { model | future = newFuture, ignored = newIgnored }
                    [ do TopLevel.FillQueue ]

        ------------------------------------
        -- Position
        ------------------------------------
        -- # Rewind
        -- > Put the previously played item as the current one.
        --
        Rewind ->
            let
                newActiveItem =
                    List.last model.past

                newModel =
                    { model
                        | activeItem =
                            newActiveItem
                        , future =
                            model.activeItem
                                |> Maybe.map ((flip (::)) model.future)
                                |> Maybe.withDefault model.future
                        , past =
                            model.past
                                |> List.init
                                |> Maybe.withDefault []
                    }
            in
                ($)
                    newModel
                    []
                    [ do (TopLevel.ActiveQueueItemChanged newActiveItem)
                    , do (TopLevel.FillQueue)
                    ]

        -- # Shift
        -- > Put the next item in the queue as the current one.
        --
        Shift ->
            let
                newActiveItem =
                    List.head model.future

                newModel =
                    { model
                        | activeItem =
                            newActiveItem
                        , future =
                            model.future
                                |> List.drop 1
                        , past =
                            model.activeItem
                                |> Maybe.map (List.singleton)
                                |> Maybe.map (List.append model.past)
                                |> Maybe.withDefault model.past
                    }
            in
                ($)
                    newModel
                    []
                    [ do (TopLevel.ActiveQueueItemChanged newActiveItem)
                    , do (TopLevel.FillQueue)
                    ]

        ------------------------------------
        -- Contents
        ------------------------------------
        -- # Fill
        -- > Fill the queue with items.
        --
        Fill timestamp tracks ->
            let
                nonMissingTracks =
                    nonMissingTracksOnly tracks
            in
                (!)
                    (model
                        |> checkIgnored (nonMissingTracksOnly tracks)
                        |> fill timestamp nonMissingTracks
                    )
                    []

        -- # Clear
        -- > Clear all future items and then re-fill
        --
        Clear ->
            (!)
                { model | future = [], ignored = [] }
                [ do TopLevel.FillQueue ]

        -- # Clean
        -- > Remove no-longer-existing items from the queue.
        --
        Clean tracks ->
            let
                filter item =
                    List.member item.identifiedTrack tracks

                newPast =
                    List.filter filter model.past

                newFuture =
                    List.filter filter model.future
            in
                (!)
                    { model | future = newFuture, past = newPast }
                    [ do TopLevel.FillQueue ]

        -- # Reset
        -- > Renew the queue, meaning that the auto-generated items in the queue
        --   are removed and new items are added.
        --
        Reset ->
            let
                newFuture =
                    List.filter (.manualEntry >> (==) True) model.future
            in
                (!)
                    { model | future = newFuture, ignored = [] }
                    [ do TopLevel.FillQueue ]

        ------------------------------------
        -- Combos
        ------------------------------------
        InjectFirstAndPlay track ->
            let
                ( a, b ) =
                    update (InjectFirst track { showNotification = False }) model

                ( c, d ) =
                    update (Shift) a
            in
                ($) c [] [ b, d ]

        ------------------------------------
        -- Settings
        ------------------------------------
        ToggleRepeat ->
            model
                |> (\m -> { m | repeat = not model.repeat })
                |> (\m -> ($) m [] [ Ports.toggleRepeat m.repeat, storeAdditionalUserData ])

        ToggleShuffle ->
            model
                |> (\m -> { m | shuffle = not model.shuffle })
                |> (\m -> ($) m [ do Reset ] [ storeAdditionalUserData ])

        ------------------------------------
        -- UI
        ------------------------------------
        DragItemMsg sub ->
            let
                dnd =
                    DnD.update sub model.itemDnD

                future =
                    model.future

                newFuture =
                    case dnd of
                        DnD.Dropped { origin, target } ->
                            List.move { from = origin, to = target } future

                        _ ->
                            model.future
            in
                (!) { model | future = newFuture, itemDnD = dnd } []


storeAdditionalUserData : Cmd TopLevel.Msg
storeAdditionalUserData =
    do TopLevel.DebounceStoreLocalUserData


nonMissingTracksOnly : List IdentifiedTrack -> List IdentifiedTrack
nonMissingTracksOnly =
    List.filter (Tuple.second >> .id >> (/=) Tracks.Types.missingId)


checkIgnored : List IdentifiedTrack -> Model -> Model
checkIgnored tracks model =
    -- Empty the ignored list when we are ignoring all the tracks
    if List.length model.ignored == List.length tracks then
        { model | ignored = [] }
    else
        model


fill : Date -> List IdentifiedTrack -> Model -> Model
fill timestamp nonMissingTracks model =
    case model.shuffle of
        False ->
            { model | future = Fill.ordered timestamp nonMissingTracks model }

        True ->
            { model | future = Fill.shuffled timestamp nonMissingTracks model }



-- 🌱


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.activeQueueItemEnded (\() -> Shift) ]
