/*
 * Copyright (c) Core DF. All rights reserved.
 *
 * Batch-oriented cawbs C client for the Core Auto Collector.
 *
 * Documentation: https://coreauto.coredf.com/resources
 */

#ifndef CAWBS_CAWBSBATCH_H
#define CAWBS_CAWBSBATCH_H

#include "wbs.h"

#ifdef __cplusplus
extern "C" {
#endif

wbs_result cawbsbatch_init(void);
wbs_result cawbsbatch_get_keystore(const char *keylist);

#ifdef __cplusplus
}
#endif

#endif /* CAWBS_CAWBSBATCH_H */
