(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(** Manage snapshot/revert capabilities. *)

type origin = IrminOrigin.t

module type STORE = sig

  (** A store with snapshot/revert capabilities. *)

  include IrminIdent.S

  type db
  (** Database handler. *)

  type path
  (** Database paths. *)

  val create: db -> t Lwt.t
  (** Snapshot the current state of the store. *)

  val revert: db -> t -> unit Lwt.t
  (** Revert the store to a previous state. *)

  val merge: db -> ?origin:origin -> t -> unit IrminMerge.result Lwt.t
  (** Merge the given snasphot into the current branch of the
      database. *)

  val merge_exn: db -> ?origin:origin -> t -> unit Lwt.t
  (** Same as [merge_snapshot] but raise a [Conflict] exception in
      case of conflict. *)

  val watch: db -> path -> (path * t) Lwt_stream.t
  (** Subscribe to the stream of modification events attached to a
      given path. Return an event for each modification of a
      subpath. *)

end

module Make (S: IrminBranch.STORE): STORE with type db = S.t
(** Add snapshot capabilities to a branch-consistent store. *)
