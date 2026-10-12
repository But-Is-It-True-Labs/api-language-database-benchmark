{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Concurrent.Chan
import Control.Exception (bracket)
import Control.Monad (replicateM_)
import Control.Monad.IO.Class (liftIO)

import Data.Aeson
import qualified Data.ByteString.Char8 as BS
import Data.Int
import Data.Text (Text)
import Data.Time (LocalTime)

import Database.MySQL.Simple
import Database.MySQL.Simple.FromRow

import Network.HTTP.Types.Status
import System.Environment (getEnv)

import Web.Scotty


data DbPool =
    DbPool (Chan Connection)


createPool :: ConnectInfo -> Int -> IO DbPool
createPool connectInfo size = do
    chan <- newChan

    replicateM_ size $ do
        conn <- connect connectInfo
        writeChan chan conn

    pure (DbPool chan)


withConnection :: DbPool -> (Connection -> IO a) -> IO a
withConnection (DbPool chan) =
    bracket
        (readChan chan)
        (writeChan chan)


data ParentRow = ParentRow
    Int64
    Int64
    Text
    LocalTime
    Text


instance FromRow ParentRow where
    fromRow =
        ParentRow
            <$> field
            <*> field
            <*> field
            <*> field
            <*> field


parentJson :: ParentRow -> Value
parentJson (ParentRow pid accountNumber parentStatus createdAt payload) =
    object
        [ "id" .= pid
        , "account_number" .= accountNumber
        , "status" .= parentStatus
        , "created_at" .= createdAt
        , "payload" .= payload
        ]


data ChildRow = ChildRow
    Int64
    Int64
    Int
    Int
    Text


instance FromRow ChildRow where
    fromRow =
        ChildRow
            <$> field
            <*> field
            <*> field
            <*> field
            <*> field


childJson :: ChildRow -> Value
childJson (ChildRow cid parentId sequenceNumber valueNumber payload) =
    object
        [ "id" .= cid
        , "parent_id" .= parentId
        , "sequence_number" .= sequenceNumber
        , "value_number" .= valueNumber
        , "payload" .= payload
        ]


data EventRow = EventRow
    Int64
    Int64
    Text
    LocalTime
    Text


instance FromRow EventRow where
    fromRow =
        EventRow
            <$> field
            <*> field
            <*> field
            <*> field
            <*> field


eventJson :: EventRow -> Value
eventJson (EventRow eid parentId eventType eventTime payload) =
    object
        [ "id" .= eid
        , "parent_id" .= parentId
        , "event_type" .= eventType
        , "event_time" .= eventTime
        , "payload" .= payload
        ]


data EventInput = EventInput
    { eventInputId :: Int64
    , eventInputParentId :: Int64
    , eventInputType :: Text
    , eventInputPayload :: Text
    }


instance FromJSON EventInput where
    parseJSON =
        withObject "EventInput" $ \o ->
            EventInput
                <$> o .: "id"
                <*> o .: "parent_id"
                <*> o .: "event_type"
                <*> o .: "payload"


main :: IO ()
main = do
    host <- getEnv "MYSQLHOST"
    portText <- getEnv "MYSQLPORT"
    user <- getEnv "MYSQLUSER"
    password <- getEnv "MYSQLPASSWORD"
    database <- getEnv "MYSQLDATABASE"

    let connectInfo =
            defaultConnectInfo
                { connectHost = host
                , connectPort = read portText
                , connectUser = user
                , connectPassword = password
                , connectDatabase = database
                }

    pool <-
        createPool
            connectInfo
            50

    scotty 8080 $ do

        get "/health" $ do
            ok <- liftIO $
                withConnection pool $ \conn -> do
                    result <-
                        query_
                            conn
                            "SELECT 1"
                            :: IO [Only Int]

                    pure (not (null result))

            if ok
                then json $
                    object
                        [ "status" .=
                            ("ok" :: Text)
                        ]
                else do
                    status status503

                    json $
                        object
                            [ "status" .=
                                ("database unavailable" :: Text)
                            ]


        get "/parent/:id" $ do
            pid <-
                pathParam "id"
                    :: ActionM Int64

            rows <- liftIO $
                withConnection pool $ \conn ->
                    query
                        conn
                        "SELECT id, account_number, status, created_at, payload \
                        \FROM benchmark_parent \
                        \WHERE id = ?"
                        (Only pid)
                        :: IO [ParentRow]

            case rows of
                [row] ->
                    json (parentJson row)

                _ -> do
                    status status404

                    json $
                        object
                            [ "error" .=
                                ("parent not found" :: Text)
                            ]


        get "/parent/:id/children" $ do
            pid <-
                pathParam "id"
                    :: ActionM Int64

            rows <- liftIO $
                withConnection pool $ \conn ->
                    query
                        conn
                        "SELECT id, parent_id, sequence_number, value_number, payload \
                        \FROM benchmark_child \
                        \WHERE parent_id = ? \
                        \ORDER BY id"
                        (Only pid)
                        :: IO [ChildRow]

            json (map childJson rows)


        get "/parent/:id/events" $ do
            pid <-
                pathParam "id"
                    :: ActionM Int64

            rows <- liftIO $
                withConnection pool $ \conn ->
                    query
                        conn
                        "SELECT id, parent_id, event_type, event_time, payload \
                        \FROM benchmark_event \
                        \WHERE parent_id = ? \
                        \ORDER BY event_time DESC, id DESC \
                        \LIMIT 20"
                        (Only pid)
                        :: IO [EventRow]

            json (map eventJson rows)


        get "/parent/:id/bundle" $ do
            pid <-
                pathParam "id"
                    :: ActionM Int64

            result <- liftIO $
                withConnection pool $ \conn -> do

                    parents <-
                        query
                            conn
                            "SELECT id, account_number, status, created_at, payload \
                            \FROM benchmark_parent \
                            \WHERE id = ?"
                            (Only pid)
                            :: IO [ParentRow]

                    children <-
                        query
                            conn
                            "SELECT id, parent_id, sequence_number, value_number, payload \
                            \FROM benchmark_child \
                            \WHERE parent_id = ? \
                            \ORDER BY id"
                            (Only pid)
                            :: IO [ChildRow]

                    events <-
                        query
                            conn
                            "SELECT id, parent_id, event_type, event_time, payload \
                            \FROM benchmark_event \
                            \WHERE parent_id = ? \
                            \ORDER BY event_time DESC, id DESC \
                            \LIMIT 20"
                            (Only pid)
                            :: IO [EventRow]

                    pure
                        ( parents
                        , children
                        , events
                        )

            case result of
                ([parent], children, events) ->
                    json $
                        object
                            [ "parent" .=
                                parentJson parent

                            , "children" .=
                                map childJson children

                            , "events" .=
                                map eventJson events
                            ]

                _ -> do
                    status status404

                    json $
                        object
                            [ "error" .=
                                ("parent not found" :: Text)
                            ]


        get "/account/:id/parents" $ do
            accountId <-
                pathParam "id"
                    :: ActionM Int64

            rows <- liftIO $
                withConnection pool $ \conn ->
                    query
                        conn
                        "SELECT id, account_number, status, created_at, payload \
                        \FROM benchmark_parent \
                        \WHERE account_number = ? \
                        \ORDER BY id \
                        \LIMIT 50"
                        (Only accountId)
                        :: IO [ParentRow]

            json (map parentJson rows)


        post "/event" $ do
            input <-
                jsonData
                    :: ActionM EventInput

            liftIO $
                withConnection pool $ \conn -> do
                    _ <-
                        execute
                            conn
                            "INSERT INTO benchmark_event \
                            \(id, parent_id, event_type, event_time, payload) \
                            \VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?)"
                            ( eventInputId input
                            , eventInputParentId input
                            , eventInputType input
                            , eventInputPayload input
                            )

                    pure ()

            status status201

            json $
                object
                    [ "created" .= True
                    , "id" .= eventInputId input
                    ]
