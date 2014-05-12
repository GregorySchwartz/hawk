{-# LANGUAGE OverloadedStrings #-}
-- | The string-typed version of Hawk's command-line arguments.
module System.Console.Hawk.Args.Option where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 (pack)
import Text.Printf

import Control.Monad.Trans.OptionParser


data HawkOption
    = Apply
    | Map
    | FieldDelimiter
    | LineDelimiter
    | OutputFieldDelimiter
    | OutputLineDelimiter
    | Version
    | Help
    | ContextDirectory
  deriving (Show, Eq, Enum, Bounded)

-- | In the order listed by --help.
options :: [HawkOption]
options = enumFrom minBound


delimiter :: OptionType
delimiter = nullable (Setting "delim")

-- | Interpret escape sequences, but don't worry if they're invalid.
-- 
-- >>> parseDelimiter ","
-- ","
-- 
-- >>> parseDelimiter "\\n"
-- "\n"
-- 
-- >>> parseDelimiter "\\t"
-- "\t"
-- 
-- >>> parseDelimiter "\\"
-- "\\"
parseDelimiter :: String -> ByteString
parseDelimiter s = pack $ case reads (printf "\"%s\"" s) of
    [(s', "")] -> s'
    _          -> s

-- | Almost like a string, except escape sequences are interpreted.
consumeDelimiter :: (Functor m, Monad m) => OptionConsumer m ByteString
consumeDelimiter = fmap parseDelimiter . consumeNullable "" consumeString

instance Option HawkOption where
  shortName Apply                = 'a'
  shortName Map                  = 'm'
  shortName FieldDelimiter       = 'd'
  shortName LineDelimiter        = 'D'
  shortName OutputFieldDelimiter = 'o'
  shortName OutputLineDelimiter  = 'O'
  shortName Version              = 'v'
  shortName Help                 = 'h'
  shortName ContextDirectory     = 'c'
  
  longName Apply                = "apply"
  longName Map                  = "map"
  longName FieldDelimiter       = "field-delimiter"
  longName LineDelimiter        = "line-delimiter"
  longName OutputFieldDelimiter = "output-field-delim"
  longName OutputLineDelimiter  = "output-line-delim"
  longName Version              = "version"
  longName Help                 = "help"
  longName ContextDirectory     = "context-directory"
  
  helpMsg Apply                      = ["apply <expr> to the entire table"]
  helpMsg Map                        = ["apply <expr> to each row"]
  helpMsg FieldDelimiter             = ["default whitespace"]
  helpMsg LineDelimiter              = ["default '\\n'"]
  helpMsg OutputFieldDelimiter       = ["default <field-delim>"]
  helpMsg OutputLineDelimiter        = ["default <line-delim>"]
  helpMsg Version                    = ["print version and exit"]
  helpMsg Help                       = ["this help"]
  helpMsg ContextDirectory           = ["<ctx-dir> directory, default is"
                                       ,"'~/.hawk'"]
  
  optionType Apply                = flag
  optionType Map                  = flag
  optionType FieldDelimiter       = delimiter
  optionType LineDelimiter        = delimiter
  optionType OutputFieldDelimiter = delimiter
  optionType OutputLineDelimiter  = delimiter
  optionType Version              = flag
  optionType Help                 = flag
  optionType ContextDirectory     = filePath
