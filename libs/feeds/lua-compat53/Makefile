include $(TOPDIR)/rules.mk

PKG_NAME:=lua-compat53
PKG_VERSION:=5.3.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=git://github.com/keplerproject/lua-compat-5.3.git
PKG_SOURCE_VERSION:=master

PKG_MAINTAINER:=The Lua Team
PKG_LICENSE=MIT

LUA_MODULE_PATH:=/usr/lib/lua
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/lua-compat53
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-compat53
	URL:=http://www.lua.org/manual/5.2/manual.html#6.7
	DEPENDS:= +lua
endef

define Package/lua-compat53/description
	This is a small module that aims to make it easier to write code in a Lua-5.3-style that is compatible with Lua 5.1, Lua 5.2, and Lua 5.3
endef

TARGET_CFLAGS += $(FPIC) -shared
TARGET_LDFLAGS += -llua

LUA_MODULE_PATH:=/usr/lib/lua

define Build/Compile
	$(TARGET_CROSS)gcc $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -I $(PKG_BUILD_DIR)/c-api/ -o $(PKG_BUILD_DIR)/compat53.so $(PKG_BUILD_DIR)/*.c
endef

define Package/lua-compat53/install
	$(INSTALL_DIR) $(1)/$(LUA_MODULE_PATH)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/compat53.so $(1)/$(LUA_MODULE_PATH)/
endef

$(eval $(call BuildPackage,lua-compat53))
