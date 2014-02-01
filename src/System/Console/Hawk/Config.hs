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

{-# LANGUAGE OverloadedStrings #-}
-- | Hawk's configuration is essentially defined by the user prelude.
module System.Console.Hawk.Config (
      createPreludeIfNeeded
    , defaultModules
    , defaultPrelude
    , getExtensionsFile
    , getModulesFile
    , recompileConfig
    , recompileConfig'
) where

import Control.Applicative ((<$>))
import Control.Arrow ((&&&))
import Control.Monad (when, unless)

import Data.Time
import System.EasyFile

import System.Console.Hawk.Config.Base
import System.Console.Hawk.Config.Cache
import System.Console.Hawk.Config.Compile
import System.Console.Hawk.Config.Extend
import System.Console.Hawk.Config.Parse
import System.Console.Hawk.Lock


-- | Imported at runtime even if missing from the user prelude.
--   Since they are fully qualified, they should not conflict with any
--   user-imported module.
defaultModules :: [QualifiedModule]
defaultModules = map fullyQualified [ 
                                       "Prelude"
                                     , "System.Console.Hawk.IO"
                                     , "System.Console.Hawk.Representable"
                                     , "System.Console.Hawk.Runtime"
                                     , "System.IO.Unsafe"
                                     , "Data.ByteString.Lazy.Char8"
                                     ]
  where
    fullyQualified = (id &&& Just)

defaultPrelude :: String
defaultPrelude = unlines
               [ "{-# LANGUAGE ExtendedDefaultRules, OverloadedStrings #-}"
               , "import Prelude"
               , "import qualified Data.ByteString.Lazy.Char8 as B"
               , "import qualified Data.List as L"
               ]

-- --
-- From now the code is heavy, it needs a refactoring (renaming)

-- maybe (file name, module name)
-- TODO: error handling

createPreludeIfNeeded :: IO ()
createPreludeIfNeeded = do
    dir <- getConfigDir
    createDirectoryIfMissing True dir
    configFile <- getConfigFile
    configFileExists <- doesFileExist configFile
    unless configFileExists $
        writeFile configFile defaultPrelude


-- | The path to the (cleaned-up) prelude file, and its module name.
--   We need both in order for hint to import its contents.
-- 
-- TODO: error handling
recompileConfig :: IO (String,String)
recompileConfig = do
  configFile <- getConfigFile
  cacheDir <- getCacheDir
  sourceFile <- getSourceFile
  extensionFile <- getExtensionsFile
  modulesFile <- getModulesFile
  compiledFile <- getCompiledFile
  configInfosFile <- getConfigInfosFile
  recompileConfig' configFile
                   cacheDir
                   sourceFile
                   extensionFile
                   modulesFile
                   compiledFile
                   configInfosFile

recompileConfig' :: FilePath -- ^ config file
                 -> FilePath -- ^ cache dir
                 -> FilePath -- ^ source file
                 -> FilePath -- ^ output extensions cache file
                 -> FilePath -- ^ output modules cache file
                 -> FilePath -- ^ output compiled file
                 -> FilePath -- ^ output config info path
                 -> IO (String,String)
recompileConfig' configFile
                 cacheDir
                 sourceFile
                 extensionsFile
                 modulesFile
                 compiledFile
                 configInfosFile = do
    clean
    createDirectoryIfMissing True cacheDir
    
    extensions <- readExtensions configFile
    orig_modules <- readModules extensions configFile
    orig_source <- readSource configFile
    
    let modules = extendModules extensions orig_modules
    let source = extendSource configFile extensions orig_modules orig_source
    
    cacheExtensions extensionsFile extensions
    cacheModules modulesFile modules
    cacheSource sourceFile source
    
    compile sourceFile compiledFile cacheDir
    
    let moduleName = getModuleName source
    lastModTime <- getModificationTime configFile
    writeFile configInfosFile $ unlines [sourceFile
                                         ,moduleName
                                         ,show lastModTime]
    
    return (sourceFile, moduleName)
  where
    clean :: IO ()
    clean = do
        dirExists <- doesDirectoryExist cacheDir
        when (dirExists) (removeDirectoryRecursive cacheDir)
