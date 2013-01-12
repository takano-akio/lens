{-# LANGUAGE CPP #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
#ifdef TRUSTWORTHY
{-# LANGUAGE Trustworthy #-}
#endif
-----------------------------------------------------------------------------
-- |
-- Module      :  Control.Lens.Internal.Action
-- Copyright   :  (C) 2012-2013 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  provisional
-- Portability :  non-portable
--
----------------------------------------------------------------------------
module Control.Lens.Internal.Action
  (
  -- ** Actions
    Effective(..)
  , Effect(..)
  ) where

import Control.Applicative
import Control.Applicative.Backwards
import Control.Arrow as Arrow
import Control.Comonad
import Control.Lens.Internal.Getter
import Control.Monad
import Control.Monad.Fix
import Data.Distributive
import Data.Functor.Identity
import Data.Functor.Compose
import Data.Monoid
import Data.Profunctor
import Data.Profunctor.Rep
import Data.Profunctor.Unsafe
import Data.Tagged
import Data.Traversable

-------------------------------------------------------------------------------
-- Programming with Effects
-------------------------------------------------------------------------------

-- | An 'Effective' 'Functor' ignores its argument and is isomorphic to a 'Monad' wrapped around a value.
--
-- That said, the 'Monad' is possibly rather unrelated to any 'Applicative' structure.
class (Monad m, Gettable f) => Effective m r f | f -> m r where
  effective :: m r -> f a
  ineffective :: f a -> m r

instance Effective m r f => Effective m (Dual r) (Backwards f) where
  effective = Backwards . effective . liftM getDual
  {-# INLINE effective #-}
  ineffective = liftM Dual . ineffective . forwards
  {-# INLINE ineffective #-}

instance Effective Identity r (Accessor r) where
  effective = Accessor #. runIdentity
  {-# INLINE effective #-}
  ineffective = Identity #. runAccessor
  {-# INLINE ineffective #-}

------------------------------------------------------------------------------
-- Effect
------------------------------------------------------------------------------

-- | Wrap a monadic effect with a phantom type argument.
newtype Effect m r a = Effect { getEffect :: m r }

instance Functor (Effect m r) where
  fmap _ (Effect m) = Effect m
  {-# INLINE fmap #-}

instance Gettable (Effect m r) where
  coerce (Effect m) = Effect m
  {-# INLINE coerce #-}

instance Monad m => Effective m r (Effect m r) where
  effective = Effect
  {-# INLINE effective #-}
  ineffective = getEffect
  {-# INLINE ineffective #-}

instance (Monad m, Monoid r) => Monoid (Effect m r a) where
  mempty = Effect (return mempty)
  {-# INLINE mempty #-}
  Effect ma `mappend` Effect mb = Effect (liftM2 mappend ma mb)
  {-# INLINE mappend #-}

instance (Monad m, Monoid r) => Applicative (Effect m r) where
  pure _ = Effect (return mempty)
  {-# INLINE pure #-}
  Effect ma <*> Effect mb = Effect (liftM2 mappend ma mb)
  {-# INLINE (<*>) #-}