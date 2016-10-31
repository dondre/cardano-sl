-- | MPC processing related workers.

module Pos.Worker.Mpc
       ( mpcOnNewSlot
       , mpcWorkers
       ) where

import           Control.TimeWarp.Logging  (logDebug)
import           Control.TimeWarp.Logging  (logWarning)
import           Control.TimeWarp.Timed    (Microsecond, repeatForever, sec)
import qualified Data.HashMap.Strict       as HM (toList)
import           Formatting                (build, ords, sformat, (%))
import           Serokell.Util.Exceptions  ()
import           Universum

import           Pos.Communication.Methods (announceCommitment, announceOpening,
                                            announceShares, announceVssCertificate)
import           Pos.Communication.Types   (SendCommitment (..), SendOpening (..),
                                            SendShares (..))
import           Pos.Constants             (k)
import           Pos.DHT                   (sendToNeighbors)
import           Pos.State                 (generateNewSecret, getLocalMpcData,
                                            getOurOpening, getOurShares)
import           Pos.Types                 (MpcData (..), SlotId (..))
import           Pos.WorkMode              (WorkMode, getNodeContext, ncPublicKey,
                                            ncSecretKey, ncVssKeyPair)

-- | Action which should be done when new slot starts.
mpcOnNewSlot :: WorkMode m => SlotId -> m ()
mpcOnNewSlot SlotId {..} = do
    ourPk <- ncPublicKey <$> getNodeContext
    ourSk <- ncSecretKey <$> getNodeContext
    -- TODO: should we randomise sending times to avoid the situation when
    -- the network becomes overwhelmed with everyone's messages?

    -- Generate a new commitment and opening for MPC; send the commitment.
    when (siSlot == 0) $ do
        logDebug $ sformat ("Generating secret for "%ords%" epoch") siEpoch
        (comm, _) <- generateNewSecret ourSk siEpoch
        logDebug $ sformat ("Generated secret for "%ords%" epoch") siEpoch
        () <$ sendToNeighbors (SendCommitment ourPk comm)
        logDebug "Sent commitment to neighbors"
    -- Send the opening
    when (siSlot == 2 * k) $ do
        mbOpen <- getOurOpening
        whenJust mbOpen $ \open -> do
            void . sendToNeighbors $ SendOpening ourPk open
            logDebug "Sent opening to neighbors"
    -- Send decrypted shares that others have sent us
    when (siSlot == 4 * k) $ do
        ourVss <- ncVssKeyPair <$> getNodeContext
        shares <- getOurShares ourVss
        unless (null shares) $ do
            void . sendToNeighbors $ SendShares ourPk shares
            logDebug "Sent shares to neighbors"

-- | All workers specific to MPC processing.
-- Exceptions:
-- 1. Worker which ticks when new slot starts.
mpcWorkers :: WorkMode m => [m ()]
mpcWorkers = [mpcTransmitter]

mpcTransmitterInterval :: Microsecond
mpcTransmitterInterval = sec 2

mpcTransmitter :: WorkMode m => m ()
mpcTransmitter =
    repeatForever mpcTransmitterInterval onError $
    do MpcData{..} <- getLocalMpcData
       mapM_ (uncurry announceCommitment) $ HM.toList _mdCommitments
       mapM_ (uncurry announceOpening) $ HM.toList _mdOpenings
       mapM_ (uncurry announceShares) $ HM.toList _mdShares
       mapM_ (uncurry announceVssCertificate) $ HM.toList _mdVssCertificates
  where
    onError e =
        mpcTransmitterInterval <$
        logWarning (sformat ("Error occured in mpcTransmitter: "%build) e)

