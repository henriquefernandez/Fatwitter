{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
module Handler.User where

import Import
import Data.Maybe
import Control.Applicative
import qualified Data.Text as DT
import Database.Persist.Postgresql

-- HELPERS

import Helpers.Application (applicationLayout,applicationNotLoggedLayout,redirectOut)
import Helpers.User (formUser, 
                     EditUser, 
                     formEditUser,
                     editUserName,
                     editUserIdent,
                     editUserColor,
                     editUserDescription,
                     editUserEmail,
                     validateIdentAlreadyExists,
                     validateEmailAlreadyExists,
                     formUploadProfileImage)

-- WEB

getHomeUserR :: Handler Html
getHomeUserR = do 
    userid <- lookupSession "UserId"
    case userid of
        Nothing -> redirectOut
        Just userid -> do
            loggeduser <- runDB $ get404 (read (unpack (userid)))
            followersnumber <- runDB $ count [UserFollowerUserId ==. (read (unpack (userid)))]
            followingnumber <- runDB $ count [UserFollowerFollowerUser ==. (read (unpack (userid)))]
            tweetsnumber <- runDB $ count [TweetUserId ==. (read (unpack (userid))), TweetParenttweetid ==. Nothing]
            loggeduserid <- return (read (unpack userid)) :: Handler UserId
            applicationLayout $ do 
                $(widgetFile "user/home")

getNewUserR :: Handler Html
getNewUserR = do
    (widget,enctype) <- generateFormPost formUser
    flashmsg <- getMessage
    applicationNotLoggedLayout $ do 
        $(widgetFile "user/new")


postCreateUserR :: Handler Value
postCreateUserR = do
    ((result,_),_) <- runFormPost formUser
    case result of 
        FormSuccess user -> do 
            validationIdentAlreadyExists <- (validateIdentAlreadyExists user Nothing)
            case validationIdentAlreadyExists of
                False -> redirect NewUserR
                True -> do
                    validationEmailAlreadyExists <- (validateEmailAlreadyExists user Nothing)
                    case validationEmailAlreadyExists of
                        False -> redirect NewUserR
                        True -> do
                            userid <- runDB $ insert user 
                            setSession "UserId" (DT.pack (show userid))
                            redirect HomeUserR
        _ -> redirect NewUserR

getEditUserR :: Handler Html
getEditUserR = do    
    userid <- lookupSession "UserId"
    case userid of
        Nothing -> redirectOut
        Just userid -> do
            loggeduser <- runDB $ get404 (read (unpack (userid)))
            followersnumber <- runDB $ count [UserFollowerUserId ==. (read (unpack (userid)))]
            followingnumber <- runDB $ count [UserFollowerFollowerUser ==. (read (unpack (userid)))]
            tweetsnumber <- runDB $ count [TweetUserId ==. (read (unpack (userid))), TweetParenttweetid ==. Nothing]
            loggeduserid <- return (read (unpack userid)) :: Handler UserId
            flashmsg <- getMessage
            (widget,enctype) <- generateFormPost (formEditUser loggeduser)
            (widgetProfileImage, enctypeProfileImage) <- generateFormPost formUploadProfileImage
            applicationLayout $ do 
                $(widgetFile "user/edit")

postEditUserR :: Handler Html
postEditUserR = do 
    userid <- lookupSession "UserId"
    case userid of
        Nothing -> redirectOut
        Just userid -> do
            loggeduser <- runDB $ get404 (read (unpack (userid)))
            loggeduserid <- return (read (unpack userid)) :: Handler UserId
            ((result,_),_) <- runFormPost (formEditUser loggeduser)
            case result of 
                FormSuccess editUser -> do
                    validationIdentAlreadyExists <- (validateIdentAlreadyExists loggeduser (Just editUser))
                    case validationIdentAlreadyExists of
                        False -> redirect EditUserR
                        True -> do
                            validationEmailAlreadyExists <- (validateEmailAlreadyExists loggeduser (Just editUser))
                            case validationEmailAlreadyExists of
                                False -> redirect EditUserR
                                True -> do
                                    runDB $ update loggeduserid [UserName =. (editUserName editUser), UserIdent =. (editUserIdent editUser), UserColor =. (editUserColor editUser), UserDescription =. (editUserDescription editUser), UserEmail =. (editUserEmail editUser)]
                                    setMessage "Success! User edited"
                                    redirect EditUserR
                _ -> do
                    setMessage "An unexpected error occurred !"
                    redirect EditUserR

postEditProfileImageR :: Handler Html 
postEditProfileImageR = do 
    userid <- lookupSession "UserId"
    case userid of
        Nothing -> redirectOut
        Just userid -> do
            loggeduser <- runDB $ get404 (read (unpack (userid))) :: Handler User
            loggeduserid <- return (read (unpack userid)) :: Handler UserId
            ((result,_),_) <- runFormPost formUploadProfileImage
            case result of 
                FormSuccess file -> do 
                    liftIO $ fileMove file ("static/img/users/" Prelude.++ (unpack $ fileName file))
                    runDB $ update loggeduserid [UserProfileimage =. (Just (fileName file))]
                    setMessage "Success! Profile user image edited"
                    redirect EditUserR
                _ -> do
                    setMessage "An unexpected error occurred !"
                    redirect EditUserR


getFollowersUserR :: Handler Html
getFollowersUserR = do 
    userid <- lookupSession "UserId"
    case userid of
        Nothing -> redirectOut
        Just userid -> do
            loggeduser <- runDB $ get404 (read (unpack (userid)))
            followersnumber <- runDB $ count [UserFollowerUserId ==. (read (unpack (userid)))]
            followingnumber <- runDB $ count [UserFollowerFollowerUser ==. (read (unpack (userid)))]
            tweetsnumber <- runDB $ count [TweetUserId ==. (read (unpack (userid))), TweetParenttweetid ==. Nothing]
            loggeduserid <- return (read (unpack userid)) :: Handler UserId
            followersuserentity <- runDB $ selectList [UserFollowerUserId ==. (read (unpack (userid)))] []
            followersusersids <- return $ Prelude.map (\x -> userFollowerFollowerUser (entityVal x)) followersuserentity
            followersusers <- sequence $ Prelude.map (\followeruserid -> runDB $ get404 followeruserid) followersusersids
            applicationLayout $ do 
                $(widgetFile "user/followers")
                
getFollowingsUserR :: Handler Html
getFollowingsUserR = do
    userid <- lookupSession "UserId"
    case userid of
        Nothing -> redirectOut
        Just userid -> do
            loggeduser <- runDB $ get404 (read (unpack (userid)))
            followersnumber <- runDB $ count [UserFollowerUserId ==. (read (unpack (userid)))]
            followingnumber <- runDB $ count [UserFollowerFollowerUser ==. (read (unpack (userid)))]
            tweetsnumber <- runDB $ count [TweetUserId ==. (read (unpack (userid))), TweetParenttweetid ==. Nothing]
            loggeduserid <- return (read (unpack userid)) :: Handler UserId
            followinguserentity <- runDB $ selectList [UserFollowerFollowerUser ==. (read (unpack (userid)))] []
            followingusersids <- return $ Prelude.map (\x -> userFollowerUserId (entityVal x)) followinguserentity
            followingusers <- sequence $ Prelude.map (\followeruserid -> runDB $ get404 followeruserid) followingusersids
            applicationLayout $ do 
                $(widgetFile "user/followings")
                
-- API

postFollowUserR :: UserId -> UserId -> Handler Value
postFollowUserR userfollowingid userfollowedid = do 
    userfollowerid <- runDB $ insert (UserFollower userfollowedid userfollowingid)
    sendStatusJSON created201 (object ["resp" .= (fromSqlKey userfollowerid)])


deleteUnfollowUserR :: UserId -> UserId -> Handler Value
deleteUnfollowUserR userfollowingid userfollowedid = do
    runDB $ deleteWhere [UserFollowerUserId ==. userfollowedid, UserFollowerFollowerUser ==. userfollowingid]
    sendStatusJSON noContent204 (object ["userfollowingiddeleted" .= userfollowingid, "userfollowediddeleted" .= userfollowedid])

