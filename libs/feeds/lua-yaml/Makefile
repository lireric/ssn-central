include $(TOPDIR)/rules.mk

PKG_NAME:=lua-yaml
PKG_VERSION:=5.1.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME).tar.xz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)
PKG_SOURCE_URL:=git://github.com/acd/lua-yaml.git
PKG_SOURCE_VERSION:=master

PKG_MAINTAINER:=Lua binding for Kirill Siminov's excellent LibYAML
PKG_LICENSE:=MIT

LUA_MODULE_PATH:=/usr/lib/lua
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/lua-yaml
	SUBMENU:=Lua
	SECTION:=lang
	CATEGORY:=Languages
	TITLE:=lua-yaml
	URL:=https://github.com/acd/lua-yaml
	DEPENDS:= +lua
endef

define Package/lua-yaml/description
	This module is a Lua binding for Kirill Siminov's excellent LibYAML
endef

TARGET_CFLAGS += $(FPIC) -shared
TARGET_LDFLAGS += -llua

LUA_MODULE_PATH:=/usr/lib/lua

define Build/Compile
	$(TARGET_CROSS)gcc $(TARGET_CFLAGS) $(TARGET_LDFLAGS) -I $(PKG_BUILD_DIR) -o $(PKG_BUILD_DIR)/yaml.so $(PKG_BUILD_DIR)/*.c
endef

define Package/lua-yaml/install
	$(INSTALL_DIR) $(1)/$(LUA_MODULE_PATH)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/yaml.so $(1)/$(LUA_MODULE_PATH)/
endef

$(eval $(call BuildPackage,lua-yaml))
