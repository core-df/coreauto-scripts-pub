// Copyright (c) Core DF. All rights reserved.

package com.coredf.cawbs

final case class Result(
    statusCode: Int,
    error: Option[Any] = None,
    payload: Option[Any] = None,
    answer: Option[Map[String, Any]] = None
):
  def toMap: Map[String, Any] =
    Map("status_code" -> statusCode) ++
      error.map("error" -> _).toMap ++
      payload.map("payload" -> _).toMap ++
      answer.map("answer" -> _).toMap
