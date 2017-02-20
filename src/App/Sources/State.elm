module Sources.State exposing (..)

import Navigation
import Sources.Types exposing (..)


-- Services

import Sources.Services.AmazonS3


-- 💧


initialModel : Model
initialModel =
    { newSource = AmazonS3 Sources.Services.AmazonS3.initialProperties }


initialCommands : Cmd Msg
initialCommands =
    Cmd.none



-- 🔥


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetNewSource source ->
            (!) { model | newSource = source } []

        SetNewSourceProperty source propKey propValue ->
            let
                updatedSource =
                    case source of
                        AmazonS3 sourceData ->
                            propValue
                                |> Sources.Services.AmazonS3.translateTo sourceData propKey
                                |> AmazonS3
            in
                (!) { model | newSource = updatedSource } []
