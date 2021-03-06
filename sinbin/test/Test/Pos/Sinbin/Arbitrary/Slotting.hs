{-# OPTIONS_GHC -fno-warn-orphans #-}

-- | Arbitrary instances for Pos.Slotting types (sinbin package)

module Test.Pos.Sinbin.Arbitrary.Slotting () where

import           Universum

import           Test.QuickCheck (Arbitrary (..), arbitrary, oneof)
import           Test.QuickCheck.Arbitrary.Generic (genericArbitrary,
                     genericShrink)

import           Pos.Sinbin.Slotting.Types (EpochSlottingData (..),
                     SlottingData, createInitSlottingData)

import           Test.Pos.Core.Arbitrary ()

instance Arbitrary EpochSlottingData where
    arbitrary = genericArbitrary
    shrink = genericShrink

instance Arbitrary SlottingData where
    -- Fixed instance since it's impossible to create and instance
    -- where one creates @SlottingData@ without at least two parameters.
    arbitrary = oneof [ createInitSlottingData <$> arbitrary <*> arbitrary ]
