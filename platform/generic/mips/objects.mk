#
# SPDX-License-Identifier: BSD-2-Clause
#

carray-platform_override_modules-$(CONFIG_PLATFORM_MIPS_P8700) += mips
platform-objs-$(CONFIG_PLATFORM_MIPS_P8700) += mips/p8700.o
platform-objs-$(CONFIG_PLATFORM_MIPS_P8700) += mips/stw.o
platform-objs-$(CONFIG_PLATFORM_MIPS_P8700) += mips/cps-vec.o
platform-dtb-$(CONFIG_PLATFORM_MIPS_P8700) += mips/mips,boston-p8700.dtb
