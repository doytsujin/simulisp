{-# LANGUAGE TupleSections #-}

module NetlistParser (netlistParser) where

import Control.Exception (assert)
import Control.Monad
import Control.Applicative hiding ((<|>), choice, many)
import Data.List

import Text.Parsec hiding (token)
import Text.Parsec.Char
import Text.Parsec.String

import NetlistAST

netlistParser :: Parser Program
netlistParser = spaces *> netlist <* eof

token = (<* spaces)

identStartChar = letter <|> char '_'
identChar = identStartChar <|> digit <|> char '\''
keyword x = token . try $ string x *> notFollowedBy identChar
punctuation = token . char

netlist = Pr <$> inputs <*> outputs <*> vars
             <*> (keyword "IN" equations

ident = token ( (:) <$> identStartChar <*> many identChar )


bigList header eltParser = keyword header
                           *> eltParser `sepBy` (punctuation ',')

inputs = bigList "INPUT" ident
outputs = bigList "OUTPUT" ident
vars = bigList "VAR" var
  where var = do x <- ident
                 n_ <- optionMaybe (punctuation ':' *> many1 digit)
                 return . (x,) $ case n_ of
                   Nothing -> TBit
                   Some s -> TBitArray (read s)

equations = many equation

equation = do z <- ident
              punctuation '='
              e <- exp
              return (z, e)

-- every choice is determined by the heading keyword except arg
--   --> put arg at the end
exp = choice [ k "NOT" $ Enot <$> arg
             , k "REG" $ Ereg <$> ident
             , k "MUX" $ Emux <$> arg <*> arg <*> arg
             , k "ROM" $ Erom <$> int <*> int <*> arg
             , k "RAM" $ Eram <$> int <*> int <*> int
             , k "CONCAT" $ Econcat <$> arg <*> arg
             , k "SELECT" $ Eselect <$> int <*> arg
             , k "SLICE" $ Eslice <$> int <*> int <*> arg
             , binop
             , arg
             ]
  where
    binop = choice . map (\name op -> k name $ Ebinop op <$> arg <*> arg)
            $ [("AND", And), ("OR", Or), ("NAND", Nand), ("XOR", Xor)]
    k x p = keyword x *> p
    int = foldl' (\x y -> 10*x + digitToInt y) 0 <$> many1 digit
    arg = try (Aconst <$> const) <|> Avar <$> ident
    const = to_const <$> many1 bit
    bit =     (False <$ char '0') <|> (True <$ char '1')
          <|> (False <$ char 'f') <|> (True <$ char 't')
    to_const [] = assert False
    to_const [b] = VBit b
    to_const bs = VBitArray bs
    
  
