// Copyright (C) Justin Ethier (2021).  All Rights Reserved.
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include "cyclone/types.h"
static object quote_sequentially_91consistent;
static object quote_acquire_91release;
static object quote_release;
static object quote_acquire;
static object quote_relaxed;

memory_order scm2c_memory_order(object mo) {
  if (mo == quote_acquire_91release) {
     return memory_order_acq_rel;
  } else if (mo == quote_release) {
            return memory_order_release;
  } else if (mo == quote_acquire) {
            return memory_order_acquire;
  } else if (mo == quote_relaxed) {
            return memory_order_relaxed;
  } else {
            return memory_order_seq_cst;
  }
}
