{-# LANGUAGE OverloadedStrings #-}

import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (forever)
import Control.Exception (finally)
import Data.Char (isSpace)
import Data.Monoid ((<>))
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

import Discord

-- | Prints every event as it happens
gatewayExample :: IO ()
gatewayExample = do
  tok <- T.filter (not . isSpace) <$> TIO.readFile "./examples/auth-token.secret"
  dis <- loginRestGateway (Auth tok)

  _ <- forkIO $ do
    sendCommand dis (UpdateStatus (UpdateStatusOpts Nothing UpdateStatusAwayFromKeyboard True))
    threadDelay (3 * 10^6)
    sendCommand dis (UpdateStatus (UpdateStatusOpts Nothing UpdateStatusOnline False))

  finally (forever $ do x <- nextEvent dis
                        putStrLn (show x <> "\n") )
          (stopDiscord dis)

