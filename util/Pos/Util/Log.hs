{-# LANGUAGE LambdaCase #-}

module Pos.Util.Log
       ( Severity(..)
       , CanLog(..)
       , HasLoggerName(..)
       , WithLogger
       --, LogContext
       --, LogContextT
       , LoggerName
       , loggerBracket
       , logDebug
       , logInfo
       , logNotice
       , logWarning
       , logError
       , addLoggerName
       --, askLoggerName
       , usingLoggerName
       ) where

import           Universum

import           Data.Text (Text{-, unpack-})
import           Data.Text.Lazy.Builder

import qualified Katip                      as K
import qualified Katip.Core                 as KC


-- | abstract libraries' severity
data Severity = Debug | Info | Warning | Notice | Error


-- | alias - pretend not to depend on katip
type LogContext = K.KatipContext
type LogContextT = K.KatipContextT

type WithLogger m = (CanLog m, HasLoggerName m)

type LoggerName = Text

-- | compatibility
class (MonadIO m, LogContext m) => CanLog m where
    dispatchMessage :: LoggerName -> Severity -> Text -> m ()
    dispatchMessage _ s t = K.logItemM Nothing (sev2klog s) $ K.logStr t

class (MonadIO m, LogContext m) => HasLoggerName m where
    askLoggerName :: m LoggerName
    askLoggerName = askLoggerName0
    setLoggerName :: LoggerName -> m a -> m a
    setLoggerName = modifyLoggerName . const
    modifyLoggerName :: (LoggerName -> LoggerName) -> m a -> m a
    modifyLoggerName f a = addLoggerName (f "cardano-sl")$ a


-- | log a Text with severity = Debug
logDebug :: (LogContext m {-, HasCallStack -}) => Text -> m ()
logDebug msg = K.logItemM Nothing K.DebugS $ K.logStr msg

-- | log a Text with severity = Info
logInfo :: (LogContext m {-, HasCallStack -}) => Text -> m ()
logInfo msg = K.logItemM Nothing K.InfoS $ K.logStr msg

-- | log a Text with severity = Notice
logNotice :: (LogContext m {-, HasCallStack -}) => Text -> m ()
logNotice msg = K.logItemM Nothing K.NoticeS $ K.logStr msg

-- | log a Text with severity = Warning
logWarning :: (LogContext m {-, HasCallStack -}) => Text -> m ()
logWarning msg = K.logItemM Nothing K.WarningS $ K.logStr msg

-- | log a Text with severity = Error
logError :: (LogContext m {-, HasCallStack -}) => Text -> m ()
logError msg = K.logItemM Nothing K.ErrorS $ K.logStr msg


-- | get current stack of logger names
askLoggerName0 :: (MonadIO m, LogContext m) => m LoggerName
askLoggerName0 = do
    ns <- K.getKatipNamespace
    return $ toStrict $ toLazyText $ mconcat $ map fromText $ KC.intercalateNs ns

-- | push a local name
addLoggerName :: (MonadIO m, LogContext m) => LoggerName -> m a -> m a
addLoggerName t f =
    K.katipAddNamespace (KC.Namespace [t]) $ f

-- | WIP -- do not use
-- type NamedPureLogger m a = LogContextT m a
{-
newtype NamedPureLogger m a = NamedPureLogger
    { runNamedPureLogger :: LogContextT m a }
    deriving (Functor, Applicative, Monad,
              MonadThrow, LogContext)
-}
--instance (MonadIO m) => KC.Katip (NamedPureLogger m)

-- | translate Severity to Katip.Severity
sev2klog :: Severity -> K.Severity
sev2klog = \case
    Debug   -> K.DebugS
    Info    -> K.InfoS
    Notice  -> K.NoticeS
    Warning -> K.WarningS
    Error   -> K.ErrorS

-- | translate
s2kname :: Text -> K.Namespace
s2kname s = K.Namespace [s]

-- | setup logging
setupLogging :: Severity -> Text -> IO K.LogEnv
setupLogging minSev name = do
    hScribe <- K.mkHandleScribe K.ColorIfTerminal stdout (sev2klog minSev) K.V0
    K.registerScribe "stdout" hScribe K.defaultScribeSettings =<< K.initLogEnv (s2kname name) "production"

-- | provide logging in IO
usingLoggerName :: Severity -> Text -> LogContextT IO a -> IO a
usingLoggerName minSev name f = do
    le <- setupLogging minSev name
    K.runKatipContextT le () "cardano-sl" $ f

-- | bracket logging
loggerBracket :: Severity -> Text -> LogContextT IO a -> IO a
loggerBracket minSev name f = do
    bracket (setupLogging minSev name) K.closeScribes $
      \le -> K.runKatipContextT le () "cardano-sl" $ f


-- | WIP: tests to run interactively in GHCi
--
{-
test1 :: IO ()
test1 = do
    loggerBracket Info "testtest" $ do
        logInfo "This is a message"

test2 :: IO ()
test2 = do
    loggerBracket Info "testtest" $ do
        logDebug "This is a DEBUG message"

test3 :: IO ()
test3 = do
    loggerBracket Info "testtest" $ do
        logWarning "This is a warning!"
        addLoggerName "onTop" $ do
            ns <- askLoggerName
            logWarning "This is a last warning!"
            putStrLn $ "loggerName = " ++ (unpack ns)

test4 :: IO ()
test4 = do
    usingLoggerName Info "testtest" $ do
        logWarning "This is a warning!"
-}

