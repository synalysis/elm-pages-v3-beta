module Route.RedirectLinks exposing (ActionData, Data, Model, Msg, route)

import DataSource exposing (DataSource)
import Head
import Head.Seo as Seo
import Html
import Pages.Msg
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Route
import RouteBuilder exposing (StatefulRoute, StatelessRoute, StaticPayload)
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
    RouteBuilder.single
        { head = head
        , data = data
        }
        |> RouteBuilder.buildNoState { view = view }


type alias Data =
    {}


type alias ActionData =
    {}


data : DataSource Data
data =
    DataSource.succeed {}


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


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data ActionData RouteParams
    -> View (Pages.Msg.Msg Msg)
view maybeUrl sharedModel static =
    { title = "Placeholder"
    , body =
        [ Route.Login
            |> Route.link
                []
                [ Html.text "Login" ]
        ]
    }
