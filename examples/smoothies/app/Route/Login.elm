module Route.Login exposing (ActionData, Data, Model, Msg, route)

import Api.Scalar exposing (Uuid(..))
import Data.User
import DataSource exposing (DataSource)
import DataSource.Port
import Dict exposing (Dict)
import ErrorPage exposing (ErrorPage)
import Form
import Form.Field as Field
import Form.FieldView
import Form.Validation as Validation exposing (Combined, Field)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode
import Json.Encode
import MySession
import Pages.Msg
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Request.Hasura
import Route
import RouteBuilder exposing (StatefulRoute, StatelessRoute, StaticPayload)
import Server.Request as Request
import Server.Response exposing (Response)
import Server.Session as Session
import Shared
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.serverRender
        { head = head
        , data = data
        , action = action
        }
        |> RouteBuilder.buildNoState { view = view }


type alias Login =
    { username : String
    , password : String
    }


form : Form.DoneForm String (DataSource (Combined String String)) data (List (Html (Pages.Msg.Msg Msg)))
form =
    Form.init
        (\username password ->
            { combine =
                Validation.succeed
                    (\u p ->
                        attemptLogIn u p
                            |> DataSource.map
                                (\maybeUserId ->
                                    case maybeUserId of
                                        Just (Uuid userId) ->
                                            Validation.succeed userId

                                        Nothing ->
                                            Validation.fail "Username and password do not match" Validation.global
                                )
                    )
                    |> Validation.andMap username
                    |> Validation.andMap password
            , view =
                \info ->
                    [ username |> fieldView info "Username"
                    , password |> fieldView info "Password"
                    , globalErrors info
                    , Html.button []
                        [ if info.isTransitioning then
                            Html.text "Logging in..."

                          else
                            Html.text "Login"
                        ]
                    ]
            }
        )
        |> Form.field "username" (Field.text |> Field.email |> Field.required "Required")
        |> Form.field "password" (Field.text |> Field.password |> Field.required "Required")


attemptLogIn : String -> String -> DataSource (Maybe Uuid)
attemptLogIn username password =
    DataSource.Port.get "hashPassword"
        (Json.Encode.string password)
        Json.Decode.string
        |> DataSource.andThen
            (\hashed ->
                { username = username
                , expectedPasswordHash = hashed
                }
                    |> Data.User.login
                    |> Request.Hasura.dataSource
            )


fieldView :
    Form.Context String data
    -> String
    -> Field String parsed Form.FieldView.Input
    -> Html msg
fieldView formState label field =
    Html.div []
        [ Html.label []
            [ Html.text (label ++ " ")
            , field |> Form.FieldView.input []
            ]
        , errorsForField formState field
        ]


errorsForField : Form.Context String data -> Field String parsed kind -> Html msg
errorsForField formState field =
    (if True || formState.submitAttempted then
        formState.errors
            |> Form.errorsForField field
            |> List.map (\error -> Html.li [] [ Html.text error ])

     else
        []
    )
        |> Html.ul [ Attr.style "color" "red" ]


globalErrors : Form.Context String data -> Html msg
globalErrors formState =
    formState.errors
        |> Form.errorsForField Validation.global
        |> List.map (\error -> Html.li [] [ Html.text error ])
        |> Html.ul [ Attr.style "color" "red" ]


type alias Request =
    { cookies : Dict String String
    , maybeFormData : Maybe (Dict String ( String, List String ))
    }


data : RouteParams -> Request.Parser (DataSource (Response Data ErrorPage))
data routeParams =
    MySession.withSession
        (Request.succeed ())
        (\() session ->
            case session of
                Ok (Just okSession) ->
                    ( okSession
                    , okSession
                        |> Session.get "userId"
                        |> Data
                        |> Server.Response.render
                    )
                        |> DataSource.succeed

                _ ->
                    ( Session.empty
                    , { username = Nothing }
                        |> Server.Response.render
                    )
                        |> DataSource.succeed
        )


action : RouteParams -> Request.Parser (DataSource (Response ActionData ErrorPage))
action routeParams =
    MySession.withSession
        (Request.formDataWithServerValidation (form |> Form.initCombined identity))
        (\usernameDs session ->
            usernameDs
                |> DataSource.andThen
                    (\usernameResult ->
                        case usernameResult of
                            Err error ->
                                ( session
                                    |> Result.withDefault Nothing
                                    |> Maybe.withDefault Session.empty
                                , error |> render
                                )
                                    |> DataSource.succeed

                            Ok ( _, userId ) ->
                                ( session
                                    |> Result.withDefault Nothing
                                    |> Maybe.withDefault Session.empty
                                    |> Session.insert "userId" userId
                                , Route.redirectTo Route.Index
                                )
                                    |> DataSource.succeed
                    )
        )


render :
    Form.Response error
    -> Response { fields : List ( String, String ), errors : Dict String (List error) } a
render (Form.Response response) =
    Server.Response.render response


head :
    StaticPayload Data ActionData RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "elm-pages"
        , image =
            { url = Pages.Url.external "TODO"
            , alt = "elm-pages logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "TODO"
        , locale = Nothing
        , title = "TODO title" -- metadata.title -- TODO
        }
        |> Seo.website


type alias Data =
    { username : Maybe String
    }


type alias ActionData =
    { fields : List ( String, String )
    , errors : Dict String (List String)
    }


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data ActionData RouteParams
    -> View (Pages.Msg.Msg Msg)
view maybeUrl sharedModel app =
    { title = "Login"
    , body =
        [ Html.p []
            [ Html.text
                (case app.data.username of
                    Just username ->
                        "Hello! You are already logged in."

                    Nothing ->
                        "You aren't logged in yet."
                )
            ]
        , form
            |> Form.toDynamicTransition "login"
            |> Form.renderHtml [] app.action app ()
        ]
    }
