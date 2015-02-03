--   Copyright 2013 Mario Pastorelli (pastorelli.mario@gmail.com) Samuel Gélineau (gelisam@gmail.com)
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing, software
--   distributed under the License is distributed on an "AS IS" BASIS,
--   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--   See the License for the specific language governing permissions and
--   limitations under the License.

-- | Hawk as seen from the outside world: parsing command-line arguments,
--   evaluating user expressions.
module System.Console.Hawk
  ( processArgs
  ) where


import qualified Data.ByteString.Lazy.Char8 as B

import Control.Monad.Trans.Uncertain
import Data.HaskellExpr
import Data.HaskellExpr.Base
import Data.HaskellExpr.Eval
import System.Console.Hawk.Args
import System.Console.Hawk.Args.Spec
import System.Console.Hawk.Help
import System.Console.Hawk.Interpreter
import System.Console.Hawk.Runtime.Base
import System.Console.Hawk.Runtime.HaskellExpr
import System.Console.Hawk.Version


-- | Same as if the given arguments were passed to Hawk on the command-line.
processArgs :: [String] -> IO ()
processArgs args = do
    r <- runWarningsIO $ parseArgs args
    case r of
      Left err -> failHelp err
      Right spec -> processSpec spec

-- | A variant of `processArgs` which accepts a structured specification
--   instead of a sequence of strings.
processSpec :: HawkSpec -> IO ()
processSpec Help          = help
processSpec Version       = putStrLn versionString
processSpec (Eval  e   o) = applyExpr (contextSpec e) noInput o (wrapExpr eConst (userExpression e))
processSpec (Apply e i o) = applyExpr (contextSpec e) i       o                  (userExpression e)
processSpec (Map   e i o) = applyExpr (contextSpec e) i       o (wrapExpr eMap   (userExpression e))

-- We cannot give `eTransform` a precise phantom type because the type of
-- the user expression is still unknown.
wrapExpr :: HaskellExpr (a -> b -> c) -> String -> String
wrapExpr eTransform s = code (eTransform `eAp` eUserExpression s)

applyExpr :: ContextSpec -> InputSpec -> OutputSpec -> String -> IO ()
applyExpr c i o e = do
    let contextDir = userContextDirectory c
    
    processRuntime <- runUncertainIO $ runHawkInterpreter $ do
      applyContext contextDir
      interpretExpr eProcessInput
    runHawkIO $ processRuntime hawkRuntime
  where
    hawkRuntime :: HawkRuntime
    hawkRuntime = HawkRuntime i o
    
    eProcessInput :: HaskellExpr (HawkRuntime -> HawkIO ())
    eProcessInput = eFlip `eAp` eProcessTable `eAp` eTableExpr
    
    -- turn the user expr into an expression manipulating [[B.ByteString]]
    eTableExpr :: HaskellExpr ([[B.ByteString]] -> ())
    eTableExpr = go (inputFormat i)
      where
        go RawStream              = eExpr `eComp` eHead `eComp` eHead
        go (Records _ RawRecord)  = eExpr `eComp` (eMap `eAp` eHead)
        go (Records _ (Fields _)) = eExpr
    
    -- note that the user expression needs to have a different type under each of
    -- the above modes, so we cannot give it a precise phantom type.
    eExpr :: HaskellExpr (a -> ())
    eExpr = eUserExpression e
