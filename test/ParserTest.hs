{-# OPTIONS_GHC -Wall #-}

module ParserTest where
  
import Parser.BNF
import Parser.BNF.Parsers
import Test.Hspec
import Test.Hspec.Core.Spec (SpecM)
import Text.Megaparsec
import Text.Megaparsec.String

shouldMatch :: Eq a => Either (ParseError b c) a -> a -> Bool
shouldMatch (Right x) a = x == a
shouldMatch (Left _)  _ = False

isSuccess :: Either (ParseError b c) a -> Bool
isSuccess (Right _) = True
isSuccess _         = False

runParserBool :: Parser a -> String -> Bool
runParserBool p s = isSuccess $ parse p mempty s

run :: SpecM () ()
run = do
  
  describe "lineEnd" $ do
    runLineEnd <- pure $ runParserBool $ lineEnd <* eof
    it "should accept a newline \"\\n\"" $ do
      runLineEnd "\n" `shouldBe` True
    it "should accept muliple newlines" $ do
      runLineEnd "\n\n" `shouldBe` True
    it "should ignore leading whitespaces" $ do
      runLineEnd "  \n \n" `shouldBe` True
  
  describe "ruleChar" $ do
    runRuleChar <- pure $ runParserBool ruleChar
    runRuleCharParser <- pure $ parse ruleChar mempty
    it "should accept a letter" $ do
      runRuleChar "a" `shouldBe` True
    it "should accept a digit" $ do
      runRuleChar "5" `shouldBe` True
    it "should accept a dash" $ do
      runRuleChar "-" `shouldBe` True
    it "should reject special chars" $ do
      runRuleChar "%" `shouldBe` False
    it "should reject empty strings" $ do
      runRuleChar "" `shouldBe` False
    it "should parse the character" $ do
      runRuleCharParser "x" `shouldMatch` 'x'

  describe "ruleName" $ do
    runRuleRef <- pure $ runParserBool ruleName
    runRuleRefParser <- pure $ parse ruleName mempty
    it "should reject empty strings" $ do
      runRuleRef "" `shouldBe` False
    it "should reject strings starting with a number" $ do
      runRuleRef "1bdf" `shouldBe` False
    it "should accept single char strings" $ do
      runRuleRef "a" `shouldBe` True
    it "should accept multi char strings" $ do
      runRuleRef "abc" `shouldBe` True
    it "should accept strings starting with a char" $ do
      runRuleRef "abc23" `shouldBe` True
    it "should parse the string" $ do
      runRuleRefParser "a123" `shouldMatch` "a123"
  
  describe "character1" $ do
    runCharacter1 <- pure $ runParserBool character1
    runCharacter1Parser <- pure $ parse character1 mempty
    it "should accept non special chars" $ do
      runCharacter1 "x" `shouldBe` True
    it "should accept special chars" $ do
      runCharacter1 "!" `shouldBe` True
    it "should accept single quotes" $ do
      runCharacter1 "'" `shouldBe` True
    it "should reject double quotes" $ do
      runCharacter1 "\"" `shouldBe` False
    it "should parse the character" $ do
      runCharacter1Parser "a" `shouldMatch` 'a'
  
  describe "character2" $ do
    runCharacter2 <- pure $ runParserBool character2
    runCharacter2Parser <- pure $ parse character2 mempty
    it "should accept non special chars" $ do
      runCharacter2 "x" `shouldBe` True
    it "should accept special chars" $ do
      runCharacter2 "!" `shouldBe` True
    it "should accept double quotes" $ do
      runCharacter2 "\"" `shouldBe` True
    it "should reject single quotes" $ do
      runCharacter2 "'" `shouldBe` False
    it "should parse the character" $ do
      runCharacter2Parser "a" `shouldMatch` 'a'

  describe "literal" $ do
    runLiteral <- pure $ runParserBool literal
    runLiteralParser <- pure $ parse literal mempty
    it "should parse chars in double quotes" $ do
      runLiteralParser "\"abc\"" `shouldMatch` Literal "abc"
    it "should parse chars in single quotes" $ do
      runLiteralParser "'abc'" `shouldMatch` Literal "abc"
    it "should parse chars in double quotes containing single quotes" $ do
      runLiteralParser "\"a'bc\"" `shouldMatch` Literal "a'bc"
    it "should parse chars in single quotes containing double quotes" $ do
      runLiteralParser "'a\"bc'" `shouldMatch` Literal "a\"bc"
    it "should reject empty strings" $ do
      runLiteral "" `shouldBe` False
      
  describe "term" $ do
    runTerm <- pure $ runParserBool term
    runTermParser <- pure $ parse term mempty
    it "should parse valid literals" $ do
      runTermParser "'abcdef'" `shouldMatch` Literal "abcdef"
    it "should parse valid rules" $ do
      runTermParser "<abc>" `shouldMatch` (RuleRef "abc")
    it "should reject empty references" $ do
      runTerm "<>" `shouldBe` False
    it "should reject whitespace-only references" $ do
      runTerm "< >" `shouldBe` False

  describe "list" $ do
    runList <- pure $ parse list mempty
    it "should parse a single term" $ do
      runList "'abc'" `shouldMatch` [Literal "abc"]
    it "should parse multiple rules" $ do
      runList "<abc><def>" `shouldMatch` 
        [RuleRef "abc", RuleRef "def"]
    it "should parse multiple terms" $ do
      runList "'abc'\"x\"" `shouldMatch` 
        [Literal "abc", Literal "x"]
    it "should parse mixed rules and literals" $ do
      runList "<abc><def>'x'<abc>'literal'" `shouldMatch` 
        [RuleRef "abc", RuleRef "def", 
         Literal "x", RuleRef "abc", Literal "literal"]
    it "should be insensitive to whitespaces" $ do
      runList "'abc' \"x\"" `shouldMatch` 
        [Literal "abc", Literal "x"]
         
  describe "expression" $ do
    runDescription <- pure $ parse expression mempty
    it "should parse a single term" $ do
      runDescription "'abc'" `shouldMatch` [[Literal"abc"]]
    it "should parse terms connected by \"or\", i.e. \"|\"" $ do
      runDescription "'abc'|'def'" `shouldMatch` 
        [[Literal "abc"], [Literal "def"]]
    it "should parse complex terms connected by \"or\"" $ do
      runDescription "'abc'<x>|<y>'def'" `shouldMatch` 
        [[Literal "abc", RuleRef "x"],
         [RuleRef "y", Literal "def"]]
    it "should be insensitive to whitespaces around \"|\"" $ do
      runDescription "'abc'  <x> | <y>  'def'" `shouldMatch` 
        [[Literal "abc", RuleRef "x"],
         [RuleRef "y", Literal "def"]]
    it "should be insensitive to whitespaces around \"|\" with multiple \"or\"s" $ do
      runDescription "'x' | 'y' | 'z'" `shouldMatch` 
        [[Literal "x"], [Literal "y"], [Literal "z"]]
  
  describe "rule" $ do
    runRule <- pure $ parse rule mempty
    it "should parse a simple rule" $ do
      runRule "<ab>::=<ab>" `shouldMatch` RuleDefinition 
        "ab" [[RuleRef "ab"]]
    it "should parse a simple rule with rule name" $ do
      runRule "<ab>::='x'" `shouldMatch` RuleDefinition 
        "ab" [[Literal "x"]]
    it "should parse a rule ending with a new line" $ do
      runRule "<ab>::='x'\n" `shouldMatch` RuleDefinition 
        "ab" [[Literal "x"]]
    it "should be insensitive to whitespaces" $ do
      runRule " <ab>   ::=   'x'  " `shouldMatch` RuleDefinition 
        "ab" [[Literal "x"]]
        
  describe "syntax" $ do 
    runSyntax <- pure $ parse syntax mempty
    it "should parse two lines of rules" $ do
      runSyntax "<a>::='b'\n<c>::=<d>" `shouldMatch` BNFDefinition
        [RuleDefinition "a" [[Literal "b"]],
         RuleDefinition "c" [[RuleRef "d"]]]
    it "should parse two lines of rules ending with newline and spaces" $ do
      runSyntax "<a>::='b'\n<c>::=<d>\n  " `shouldMatch` BNFDefinition
        [RuleDefinition "a" [[Literal "b"]],
         RuleDefinition "c" [[RuleRef "d"]]]
