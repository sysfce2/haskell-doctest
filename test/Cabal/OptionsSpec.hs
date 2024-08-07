{-# LANGUAGE CPP #-}
module Cabal.OptionsSpec (spec) where

import           Imports

import           Test.Hspec

import           System.IO
import           System.IO.Silently
import           System.Exit
import           System.Process
import           Data.Set ((\\))
import qualified Data.Set as Set

import qualified Cabal.ReplOptionsSpec as Repl

import           Cabal.Options

spec :: Spec
spec = do
  describe "replOnlyOptions" $ do
    it "is the set of options that are unique to 'cabal repl'" $ do
      build <- Set.fromList . lines <$> readProcess "cabal" ["build", "--list-options"] ""
      repl <- Set.fromList . lines <$> readProcess "cabal" ["repl", "--list-options"] ""
      Set.toList replOnlyOptions `shouldMatchList` Set.toList (repl \\ build)

  describe "rejectUnsupportedOptions" $ do
    it "produces error messages that are consistent with 'cabal repl'" $ do
      let
        shouldFail :: HasCallStack => String -> IO a -> Expectation
        shouldFail command action = do
          hCapture_ [stderr] (action `shouldThrow` (== ExitFailure 1))
            `shouldReturn` "Error: cabal: unrecognized '" <> command <> "' option `--installdir'\n"

#ifndef mingw32_HOST_OS
      shouldFail "repl" $ call "cabal" ["repl", "--installdir"]
#endif
      shouldFail "doctest" $ rejectUnsupportedOptions ["--installdir"]

    context "with --list-options" $ do
      it "lists supported command-line options" $ do
        repl <- Set.fromList . lines <$> readProcess "cabal" ["repl", "--list-options"] ""
        doctest <- Set.fromList . lines <$> capture_ (rejectUnsupportedOptions ["--list-options"] `shouldThrow` (== ExitSuccess))
        Set.toList (doctest \\ repl) `shouldMatchList` []
        Set.toList (repl \\ doctest) `shouldMatchList` Set.toList Repl.unsupported

  describe "discardReplOptions" $ do
    it "discards 'cabal repl'-only options" $ do
      discardReplOptions [
          "-w", "ghc-9.10"
        , "--build-depends=foo"
        , "--build-depends", "foo"
        , "-bfoo"
        , "-b", "foo"
        , "--disable-optimization"
        , "--enable-multi-repl"
        , "--repl-options", "foo"
        , "--repl-options=foo"
        , "--allow-newer"
        ] `shouldBe` ["--with-compiler=ghc-9.10", "--disable-optimization", "--allow-newer"]
