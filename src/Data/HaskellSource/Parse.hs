{-# LANGUAGE OverloadedStrings, PackageImports #-}
-- | Parser combinators for processing HaskellSource.
module Data.HaskellSource.Parse where

import Control.Applicative
import Control.Monad
import "mtl" Control.Monad.Identity
import "mtl" Control.Monad.Trans
import Control.Monad.Trans.State
import Control.Monad.Trans.Writer
import qualified Data.ByteString.Char8 as B
import Data.Functor.Identity

import Data.Chunks
import Data.HaskellSource


-- | Consume part of a HaskellSource, splitting it into chunks along the way.
type SourceParser a = StateT HaskellSource               -- yet to be parsed
                    ( WriterT (StickyList HaskellSource) -- emitted chunks
                      Maybe) a                           -- backtracking


-- | Print the consumed chunks, the result, and the remaining lines.
-- >>> testP "foo" (return 42)
-- 42
-- "foo"
testP :: Show a => String -> SourceParser a -> IO ()
testP str = go . runWriterT . (`runStateT` source)
  where
    source = parseSource (B.pack str)
    
    go Nothing = putStrLn "Nothing"
    go (Just ((r, xs), chunks)) = do
      mapM_ show_chunk $ toLists chunks
      print r
      mapM_ show_line xs
    
    show_line (Left s) = print s
    show_line (Right s) = print s
    
    show_chunk xs = do
        mapM_ show_line xs
        putStrLn "==="

-- |
-- >>> testP "foo" eof
-- Nothing
-- 
-- >>> testP "" eof
-- ()
eof :: SourceParser ()
eof = do
    [] <- get
    return ()

-- |
-- >>> testP "foo\nbar\n" line
-- "foo"
-- "foo"
-- "bar"
-- 
-- Make sure the state is backtracked after a failed alternative.
-- 
-- >>> testP "foo\nbar\n" (line >> eof)
-- Nothing
-- 
-- >>> testP "foo\nbar\n" ((line >> eof) <|> (line >> return ()))
-- "foo"
-- ()
-- "bar"
line :: SourceParser B.ByteString
line = do
    (x:xs) <- get
    put xs
    lift $ tell $ singleton [x]
    case x of
      Left s -> return s
      Right s -> return (B.pack s)

-- |
-- >>> testP "foo\nbar\nbaz\n" (line >> line >> next_chunk >> line)
-- "foo"
-- "bar"
-- ===
-- "baz"
-- ()
next_chunk :: SourceParser ()
next_chunk = lift $ tell $ divider

-- |
-- >>> testP "-- single line comment" comment
-- "-- single line comment"
-- ["-- single line comment"]
-- 
-- >>> testP "{- multi\n   line\n   comment -}\n" comment
-- "{- multi"
-- "   line"
-- "   comment -}"
-- ["{- multi","   line","   comment -}"]
comment :: SourceParser [B.ByteString]
comment = single_line_comment <|> multi_line_comment
  where
    single_line_comment = do
        x <- line
        guard ("--" `B.isPrefixOf` x)
        return [x]
    
    -- nested comments not supported
    multi_line_comment = do
        x <- line
        guard ("{-" `B.isPrefixOf` x)
        xs <- inside_comment x
        return (x:xs)
    
    inside_comment s | "-}" `B.isInfixOf` s = return []
    inside_comment s | otherwise = do
        x <- line
        xs <- inside_comment x
        return (x:xs)

-- |
-- >>> testP "module Foo where\nmain = 42\n" module_declaration
-- "module Foo where"
-- ["module Foo where"]
-- "main = 42"
-- 
-- >>> testP "module Foo\n  ( main\n  ) where\nmain = 42\n" module_declaration
-- "module Foo"
-- "  ( main"
-- "  ) where"
-- ["module Foo","  ( main","  ) where"]
-- "main = 42"
module_declaration :: SourceParser [B.ByteString]
module_declaration = do
    x <- line
    guard ("module " `B.isPrefixOf` x)
    xs <- inside_declaration x
    return (x:xs)
  where
    inside_declaration s | " where" `B.isInfixOf` s = return []
    inside_declaration s | otherwise = do
        x <- line
        xs <- inside_declaration x
        return (x:xs)
