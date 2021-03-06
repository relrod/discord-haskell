{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StrictData #-}

-- | Data structures needed for interfacing with the Websocket
--   Gateway
module Discord.Types.Gateway where

import System.Info

import qualified Data.Text as T
import Data.Monoid ((<>))
import Data.Time (UTCTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import Data.Aeson
import Data.Aeson.Types
import Data.Maybe (fromMaybe)
import Text.Read (readMaybe)

import Discord.Types.Prelude
import Discord.Types.Events

-- | Represents data sent and received with Discord servers
data GatewayReceivable
  = Dispatch Event Integer
  | HeartbeatRequest Integer
  | Reconnect
  | InvalidSession Bool
  | Hello Int
  | HeartbeatAck
  | ParseError String
  deriving Show

data GatewaySendable
  = Heartbeat Integer
  | Identify Auth Bool Integer (Int, Int)
  | Resume T.Text String Integer
  | RequestGuildMembers RequestGuildMembersOpts
  | UpdateStatus UpdateStatusOpts
  | UpdateStatusVoice UpdateStatusVoiceOpts

data RequestGuildMembersOpts = RequestGuildMembersOpts
                             { requestGuildMemersGuildId :: Snowflake
                             , requestGuildMemersSearchQuery :: T.Text
                             , requestGuildMemersLimit :: Integer }

data UpdateStatusVoiceOpts = UpdateStatusVoiceOpts
                           { updateStatusVoiceGuildId :: Snowflake
                           , updateStatusVoiceChannelId :: Maybe Snowflake
                           , updateStatusVoiceIsMuted :: Snowflake
                           , updateStatusVoiceIsDeaf :: Snowflake
                           }

data UpdateStatusOpts = UpdateStatusOpts
                      { updateStatusSince :: Maybe UTCTime
                      -- todo , updateStatusGame :: Activity
                      , updateStatusNewStatus :: UpdateStatusTypes
                      , updateStatusAFK :: Bool
                      }

data UpdateStatusTypes = UpdateStatusOnline
                       | UpdateStatusDoNotDisturb
                       | UpdateStatusAwayFromKeyboard
                       | UpdateStatusInvisibleOffline
                       | UpdateStatusOffline

statusString :: UpdateStatusTypes -> T.Text
statusString s = case s of
  UpdateStatusOnline -> "online"
  UpdateStatusDoNotDisturb -> "dnd"
  UpdateStatusAwayFromKeyboard -> "idle"
  UpdateStatusInvisibleOffline -> "invisible"
  UpdateStatusOffline -> "offline"

instance FromJSON GatewayReceivable where
  parseJSON = withObject "payload" $ \o -> do
    op <- o .: "op" :: Parser Int
    case op of
      0  -> do etype <- o .: "t"
               ejson <- o .: "d"
               case ejson of
                 Object hm -> Dispatch <$> eventParse etype hm <*> o .: "s"
                 _other -> Dispatch (UnknownEvent ("Dispatch payload wasn't an object") o)
                                  <$> o .: "s"
      1  -> HeartbeatRequest . fromMaybe 0 . readMaybe <$> o .: "d"
      7  -> pure Reconnect
      9  -> InvalidSession <$> o .: "d"
      10 -> do od <- o .: "d"
               int <- od .: "heartbeat_interval"
               pure (Hello int)
      11 -> pure HeartbeatAck
      _  -> fail ("Unknown Receivable payload ID:" <> show op)

-- instance FromJSON GatewaySendable where
--   parseJSON = withObject "payload" $ \o -> do
--     op <- o .: "op" :: Parser Int
--     case op of
--       1  -> Heartbeat . fromMaybe 0 . readMaybe <$> o .: "d"
--       2  -> do od <- o .: "d"
--                tok <- od .: "token"
--                compress <- od .:? "compress" .!= False
--
--       _  -> fail ("Unknown Sendable payload ID:" <> show op)

instance ToJSON GatewaySendable where
  toJSON (Heartbeat i) = object [ "op" .= (1 :: Int), "d" .= if i <= 0 then "null" else show i ]
  toJSON (Identify token compress large shard) = object [
      "op" .= (2 :: Int)
    , "d"  .= object [
        "token" .= authToken token
      , "properties" .= object [
          "$os"                .= os
        , "$browser"           .= ("discord-haskell" :: String)
        , "$device"            .= ("discord-haskell" :: String)
        , "$referrer"          .= (""                :: String)
        , "$referring_domain"  .= (""                :: String)
        ]
      , "compress" .= compress
      , "large_threshold" .= large
      , "shard" .= shard
      ]
    ]
  toJSON (UpdateStatus (UpdateStatusOpts since status afk)) = object [
      "op" .= (3 :: Int)
    , "d"  .= object [
        "since" .= case since of Nothing -> Nothing
                                 Just s -> Just ((10^6) * (utcTimeToPOSIXSeconds s))
      , "afk" .= afk
      , "status" .= statusString status
      , "game" .= (Nothing :: Maybe ())
      -- todo , "game"       .= object [
      --        "name" .= game
      --      ]
      ]
    ]
  toJSON (UpdateStatusVoice (UpdateStatusVoiceOpts guild channel mute deaf)) =
    object [
      "op" .= (4 :: Int)
    , "d"  .= object [
        "guild_id"   .= guild
      , "channel_id" .= channel
      , "self_mute"  .= mute
      , "self_deaf"  .= deaf
      ]
    ]
  toJSON (Resume token session seqId) = object [
      "op" .= (6 :: Int)
    , "d"  .= object [
        "token"      .= token
      , "session_id" .= session
      , "seq"        .= seqId
      ]
    ]
  toJSON (RequestGuildMembers (RequestGuildMembersOpts guild query limit)) =
    object [
      "op" .= (8 :: Int)
    , "d"  .= object [
        "guild_id" .= guild
      , "query"    .= query
      , "limit"    .= limit
      ]
    ]
