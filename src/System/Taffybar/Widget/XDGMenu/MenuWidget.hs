-----------------------------------------------------------------------------
-- |
-- Module      : System.Taffybar.Widget.XDGMenu.MenuWidget
-- Copyright   : 2017 Ulf Jasper
-- License     : BSD3-style (see LICENSE)
--
-- Maintainer  : Ulf Jasper <ulf.jasper@web.de>
-- Stability   : unstable
-- Portability : unportable
--
-- MenuWidget provides a hierachical GTK menu containing all
-- applicable desktop entries found on the system.  The menu is built
-- according to the version 1.1 of the XDG "Desktop Menu
-- Specification", see
-- https://specifications.freedesktop.org/menu-spec/menu-spec-1.1.html
-----------------------------------------------------------------------------

module System.Taffybar.Widget.XDGMenu.MenuWidget
  (
  -- * Usage
  -- $usage
  menuWidgetNew
  )
where

import Control.Monad
import Control.Monad.IO.Class
import qualified Data.Text as T
import GI.Gtk hiding (Menu)
import GI.GdkPixbuf
import System.Directory
import System.FilePath.Posix
import System.Process
import System.Taffybar.Widget.XDGMenu.Menu

-- $usage
--
-- In order to use this widget add the following line to your
-- @taffybar.hs@ file:
--
-- > import System.Taffybar.Widget.XDGMenu.MenuWidget
-- > main = do
-- >   let menu = menuWidgetNew $ Just "PREFIX-"
--
-- The menu will look for a file named "PREFIX-applications.menu" in
-- the (subdirectory "menus" of the) directories specified by the
-- environment variables XDG_CONFIG_HOME and XDG_CONFIG_DIRS.  (If
-- XDG_CONFIG_HOME is not set or empty then $HOME/.config is used, if
-- XDG_CONFIG_DIRS is not set or empty then "/etc/xdg" is used).  If
-- no prefix is given (i.e. if you pass Nothing) then the value of the
-- environment variable XDG_MENU_PREFIX is used, if it is set.  If
-- taffybar is running inside a desktop environment like Mate, Gnome,
-- XFCE etc. the environment variables XDG_CONFIG_DIRS and
-- XDG_MENU_PREFIX should be set and you may create the menu like
-- this:
--
-- >   let menu = menuWidgetNew Nothing
--
-- Now you can use @menu@ as any other Taffybar widget.


-- | Add a desktop entry to a gtk menu by appending a gtk menu item.
addItem :: (IsMenuShell msc) =>
           msc -- ^ GTK menu
        -> MenuEntry -- ^ Desktop entry
        -> IO ()
addItem ms de = do
  item <- imageMenuItemNewWithLabel (feName de)
  set item [ widgetTooltipText := feComment de]
  setIcon item (T.unpack <$> feIcon de)
  menuShellAppend ms item
  _ <- onMenuItemActivate item $ do
    let cmd = feCommand de
    putStrLn $ "Launching '" ++ cmd ++ "'"
    _ <- spawnCommand cmd
    return ()
  return ()

-- | Add an xdg menu to a gtk menu by appending gtk menu items and
-- submenus.
addMenu :: (IsMenuShell msc) =>
           msc -- ^ GTK menu
        -> Menu -- ^ menu
        -> IO ()
addMenu ms fm = do
  let subMenus = fmSubmenus fm
      items = fmEntries fm
  when (not (null items) || not (null subMenus)) $ do
    item <- imageMenuItemNewWithLabel (T.pack $ fmName fm)
    setIcon item (fmIcon fm)
    menuShellAppend ms item
    subMenu <- menuNew
    menuItemSetSubmenu item (Just subMenu)
    mapM_ (addMenu subMenu) subMenus
    mapM_ (addItem subMenu) items

setIcon :: ImageMenuItem -> Maybe String -> IO ()
setIcon _ Nothing = return ()
setIcon item (Just iconName) = do
  iconTheme <- iconThemeGetDefault
  hasIcon <- iconThemeHasIcon iconTheme (T.pack iconName)
  mImg <- if hasIcon
          then Just <$> imageNewFromIconName (Just $ T.pack $ iconName) 16 -- FIXME: should use IconSizeMenu?
          else if isAbsolute iconName
               then
                 do
                   ex <- doesFileExist iconName
                   if ex
                   then do let defaultSize = 24 -- FIXME should auto-adjust to font size
                           pb <- pixbufNewFromFileAtScale iconName
                               defaultSize defaultSize True
                           Just <$> imageNewFromPixbuf (Just pb)
                     else return Nothing
               else return Nothing
  case mImg of
    Just img -> imageMenuItemSetImage item (Just img)
    Nothing -> putStrLn $ "Icon not found: " ++ iconName

-- | Create a new XDG Menu Widget.
menuWidgetNew :: MonadIO m => Maybe String -- ^ menu name, must end with a dash,
                              -- e.g. "mate-" or "gnome-"
              -> m GI.Gtk.Widget
menuWidgetNew mMenuPrefix = liftIO $ do
  mb <- menuBarNew
  m <- buildMenu mMenuPrefix
  addMenu mb m
  widgetShowAll mb
  toWidget mb

-- -- | Show XDG Menu Widget in a standalone frame.
-- testMenuWidget :: IO ()
-- testMenuWidget = do
--    _ <- initGUI
--    window <- windowNew
--    _ <- window `on` deleteEvent $ liftIO mainQuit >> return False
--    containerAdd window =<< menuWidgetNew Nothing
--    widgetShowAll window
--    mainGUI
