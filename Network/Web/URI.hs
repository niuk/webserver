{-# LANGUAGE OverloadedStrings #-}

{-|
  Parser for URI
-}

module Network.Web.URI
  ( URI, uriScheme, uriAuthority, uriPath, uriQuery, uriFragment
  , URIAuth, uriUserInfo, uriRegName, uriPort
  , parseURI
  , uriHostName, uriPortNumber, toURL, toURLwoPort
  , isAbsoluteURI, unEscapeString, unEscapeByteString
  ) where

import qualified Data.ByteString.Char8 as S
import Data.Char

{-|
  Abstract data type for URI
-}
data URI = URI
  { uriScheme    :: S.ByteString
  , uriAuthority :: Maybe URIAuth
  , uriPath      :: S.ByteString
  , uriQuery     :: S.ByteString
  , uriFragment  :: S.ByteString
  }

{-|
  Abstract data type for URI Authority
-}
data URIAuth = URIAuth
  { uriUserInfo :: S.ByteString
  , uriRegName  :: S.ByteString
  , uriPort     :: S.ByteString
  }

instance Show URI where
  show uri = 
    (S.unpack (uriScheme uri) ?++ "//")
    ++ (case uriAuthority uri of
          Nothing -> ""
          Just uriAuth -> show uriAuth)
    ++ S.unpack (uriPath uri)
    ++ ("?" ++? S.unpack (uriQuery uri))
    ++ ("#" ++? S.unpack (uriFragment uri))

instance Show URIAuth where
  show uriAuth =
    (S.unpack (uriUserInfo uriAuth) ?++ "@")
    ++ S.unpack (uriRegName uriAuth)
    ++ (":" ++? S.unpack (uriPort uriAuth))

a ?++ b
  | a == "" = ""
  | True = a ++ b

a ++? b
  | b == "" = ""
  | True = a ++ b

----------------------------------------------------------------

{-|
  Parsing URI.
-}
parseURI :: S.ByteString -> Maybe URI
parseURI url = Just URI {
    uriScheme = "http:"
  , uriAuthority = Just URIAuth {
        uriUserInfo = ""
      , uriRegName = host
      , uriPort = port
      }
  , uriPath = path
  , uriQuery = query
  , uriFragment = ""
  }
  where
    (auth,pathQuery) = parseURL url
    (path,query) = parsePathQuery pathQuery
    (host,port) = parseAuthority auth

parseURL :: S.ByteString -> (S.ByteString,S.ByteString)
parseURL reqUri = let (hostServ,path) = S.break (=='/') $ S.drop 7 reqUri
                  in (hostServ, checkPath path)
  where
    checkPath ""   = "/"
    checkPath path = path

parsePathQuery :: S.ByteString -> (S.ByteString,S.ByteString)
parsePathQuery = S.break (=='?')

parseAuthority :: S.ByteString -> (S.ByteString,S.ByteString)
parseAuthority hostServ
  | serv == "" = (host, "")
  | otherwise  = (host, S.tail serv)
  where
    (host,serv) = S.break (==':') hostServ

----------------------------------------------------------------

{-|
  Getting a hostname from 'URI'.
-}
uriHostName :: URI -> S.ByteString
uriHostName uri = maybe "" uriRegName $ uriAuthority uri

{-|
  Getting a port number from 'URI'.
-}
uriPortNumber :: URI -> S.ByteString
uriPortNumber uri = maybe "" uriPort $ uriAuthority uri

{-|
  Making a URL string from 'URI'.
-}
toURL :: URI -> S.ByteString
toURL uri = uriScheme uri +++ "//" +++ hostServ +++ uriPath uri +++ uriQuery uri
  where
    host = uriHostName uri
    serv = uriPortNumber uri
    hostServ = if S.null serv
               then host
               else host +++ ":" +++ serv
    (+++) = S.append

{-|
  Making a URL string from 'URI' without port.
-}
toURLwoPort :: URI -> S.ByteString
toURLwoPort uri = uriScheme uri +++ "//" +++ uriHostName uri +++ uriPath uri +++ uriQuery uri
  where
    (+++) = S.append

----------------------------------------------------------------

{-|
  Checking whether or not URI starts with \"http://\".
-}
isAbsoluteURI :: S.ByteString -> Bool
isAbsoluteURI url = "http://" `S.isPrefixOf` url

{-|
  Decoding the %XX encoding.
-}
unEscapeByteString :: S.ByteString -> S.ByteString
unEscapeByteString "" = ""
unEscapeByteString bs
  | S.head bs == '%' && S.length bs >= 3
    && isHexDigit c1 && isHexDigit c2    = dc <:> unEscapeByteString cs
  where
    [_,c1,c2] = S.unpack $ S.take 3 bs
    cs = S.drop 3 bs
    dc = chr $ digitToInt c1 * 16 + digitToInt c2
    (<:>) = S.cons
unEscapeByteString bs = c <:> unEscapeByteString cs
  where
    c = S.head bs
    cs = S.tail bs
    (<:>) = S.cons

{-|
   Decoding the %XX encoding.
 -}
unEscapeString :: String -> String
unEscapeString [] = ""
unEscapeString ('%':c1:c2:cs)
  | isHexDigit c1 && isHexDigit c2 = dc : unEscapeString cs
  where
    dc = chr $ digitToInt c1 * 16 + digitToInt c2
unEscapeString (c:cs) = c : unEscapeString cs
