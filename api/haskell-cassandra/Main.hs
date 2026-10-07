{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception
    ( SomeException
    , try
    )

import Data.Functor.Identity
    ( Identity (..)
    )

import Control.Monad.IO.Class
    ( liftIO
    )

import Data.Aeson
import Data.Int
import Data.Text
    ( Text
    )

import Data.Time
    ( UTCTime
    )

import Database.CQL.IO
    as Client

import Network.HTTP.Types.Status
import System.Environment
    ( lookupEnv
    )

import Web.Scotty


type ParentRow =
    ( Int64
    , Int64
    , Text
    , UTCTime
    , Text
    )


parentQuery
    :: PrepQuery
        R
        (Identity Int64)
        ParentRow

parentQuery =
    "SELECT id, account_number, status, created_at, payload \
    \FROM benchmark.parent_by_id \
    \WHERE id = ?"


healthQuery
    :: PrepQuery
        R
        ()
        (Identity Text)

healthQuery =
    "SELECT release_version \
    \FROM system.local"


parentJson
    :: ParentRow
    -> Value

parentJson
    ( pid
    , accountNumber
    , parentStatus
    , createdAt
    , payload
    ) =
        object
            [ "id" .=
                pid

            , "account_number" .=
                accountNumber

            , "status" .=
                parentStatus

            , "created_at" .=
                createdAt

            , "payload" .=
                payload
            ]


main :: IO ()
main = do
    host <-
        maybe
            "benchmark_cassandra"
            id
            <$> lookupEnv
                "CASSANDRA_HOST"

    let settings =
            setContacts
                host
                []

            . setPortNumber
                9042

            . setLogger
                nullLogger

            $ defSettings

    client <-
        Client.init
            settings

    scotty
        8080
        $ do

        get
            "/health"
            $ do

            result <-
                liftIO
                    $ try
                    $ runClient
                        client
                    $ query1
                        healthQuery
                        ( defQueryParams
                            One
                            ()
                        )

            case (result :: Either SomeException (Maybe (Identity Text))) of
                Right
                    (Just _) ->
                        json
                            $ object
                                [ "status" .=
                                    ("ok" :: Text)
                                ]

                _ -> do
                    status
                        status503

                    json
                        $ object
                            [ "status" .=
                                ("database unavailable" :: Text)
                            ]


        get
            "/parent/:id"
            $ do

            pid <-
                pathParam
                    "id"
                    :: ActionM Int64

            result <-
                liftIO
                    $ try
                    $ runClient
                        client
                    $ query1
                        parentQuery
                        ( defQueryParams
                            One
                            (Identity pid)
                        )

            case (result :: Either SomeException (Maybe ParentRow)) of
                Right
                    (Just row) ->
                        json
                            (parentJson row)

                Right
                    Nothing -> do

                        status
                            status404

                        json
                            $ object
                                [ "error" .=
                                    ("parent not found" :: Text)
                                ]

                Left
                    _ -> do

                        status
                            status500

                        json
                            $ object
                                [ "error" .=
                                    ("query failed" :: Text)
                                ]
