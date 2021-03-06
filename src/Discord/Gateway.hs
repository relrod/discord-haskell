{-# OPTIONS_HADDOCK prune, not-home #-}

-- | Provides a rather raw interface to the websocket events
--   through a real-time Chan
module Discord.Gateway
  ( Gateway(..)
  , startGatewayThread
  , module Discord.Types
  ) where

import Prelude hiding (log)
import Control.Exception.Safe (finally)
import Control.Concurrent.Chan (newChan, dupChan, Chan)
import Control.Concurrent (forkIO, killThread, ThreadId, MVar)

import Discord.Types (Auth, Event, GatewaySendable)
import Discord.Gateway.EventLoop (connectionLoop)
import Discord.Gateway.Cache

-- | Concurrency primitives that make up the gateway. Build a higher
--   level interface over these
data Gateway = Gateway
  { _events :: Chan Event
  , _cache :: MVar Cache
  , _gatewayCommands :: Chan GatewaySendable
  }

-- | Create a Chan for websockets. This creates a thread that
--   writes all the received Events to the Chan
startGatewayThread :: Auth -> Chan String -> IO (Gateway, ThreadId)
startGatewayThread auth log = do
  eventsWrite <- newChan
  eventsCache <- dupChan eventsWrite
  sends <- newChan
  writeFile "the-log-of-discord-haskell.txt" ""
  cache <- emptyCache
  cacheID <- forkIO $ addEvent cache eventsCache log
  tid <- forkIO $ finally (connectionLoop auth eventsWrite sends log)
                          (killThread cacheID)
  pure (Gateway eventsWrite cache sends, tid)



