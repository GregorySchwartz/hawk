module System.Console.Hawk.TestUtils where

import Control.Applicative
  ( (<$>) )
import Control.Exception
  ( bracket_ )
import Data.List
  ( foldl'
  , isSuffixOf
  , isPrefixOf )
import System.Directory
  ( createDirectory 
  , getDirectoryContents
  , getTemporaryDirectory
  , removeFile
  , removeDirectoryRecursive)
import System.FilePath
  ( FilePath
  , (</>)
  , dropExtension
  , takeExtension)


nextFilePath :: FilePath -- ^ directory
             -> String -- ^ prefix
             -> String -- ^ suffix
             -> IO FilePath -- ^ next file path available
nextFilePath dir pre post = do
    contents <- getDirectoryContents dir
    let max = foldl maybeTakeNum 0 contents
    return $ pre ++ show (max+1) ++ post
    where maybeTakeNum :: Int -> String -> Int
          maybeTakeNum acc str =
            if pre `isPrefixOf` str && post `isSuffixOf` str
                then let num = read $ take (lnum str) $ drop lpre str
                     in max acc num
                else acc
          lpre = length pre
          lnum str = length str - lpre - length post

withTempFilePath :: FilePath -- ^ directory
                 -> String -- ^ file template
                 -> (FilePath -> IO a) -- ^ action to be run with the temp file
                 -> Bool
                 -> IO a
withTempFilePath dir template action isDir = do
    let pre = dropExtension template
    let post = takeExtension template
    tempFileName <- ((</>) dir) <$> nextFilePath dir pre post
    bracket_ (create tempFileName) (delete tempFileName) (action tempFileName)
  where create fp = if isDir
                      then createDirectory fp
                      else writeFile fp "" 
        delete fp = if isDir
                      then removeDirectoryRecursive fp
                      else removeFile fp

withTempFilePath' :: String -- ^ file template
                  -> (FilePath -> IO a) -- ^ action to be run with the temp file
                  -> Bool
                  -> IO a
withTempFilePath' template action isDir = do
    tempDir <- getTemporaryDirectory
    withTempFilePath tempDir template action isDir

withTempFile' :: String
              -> (FilePath -> IO a)
              -> IO a
withTempFile' template action = withTempFilePath' template action False

withTempDir' :: String
             -> (FilePath -> IO a)
             -> IO a
withTempDir' template action = withTempFilePath' template action True
