let what =
  "This example demanstrate custom merges.\n\
   \n\
   It models log files as a sequence of lines, ordered by timestamps.\n\
   \n\
   The log files of `branch 1` and `branch 2` are merged by using the following \n\
   strategy:\n\
  \  - find the log file corresponding the lowest common ancestor: `lca`\n\
  \  - remove the prefix `lca` from `branch 1`; this gives `l1`;\n\
  \  - remove the prefix `lca` from `branch 2`; this gives `l2`;\n\
  \  - interleave `l1` and `l2` by ordering the timestamps; This gives `l3`;\n\
  \  - concatenate `lca` and `l3`; This gives the final result."

open Lwt
open Irmin_unix

let time = ref 0

(* A log entry *)
module Entry = struct
  include Tc.Pair (Tc.Int)(Tc.String)
  let compare (x, _) (y, _) = Pervasives.compare x y
  let create message =
    incr time;
    !time, message
end

(* A log file *)
module Log = struct

  module Path = Irmin.Path.String_list

  (* A log file is a list of timestamped message (one per line). *)
  include Tc.List(Entry)

  let pretty l =
    let buf = Buffer.create 1024 in
    List.iter (fun (t, m) -> Printf.bprintf buf "%04d: %s\n" t m) (List.rev l);
    Buffer.contents buf

  let timestamp = function
    | [] -> 0
    | (timestamp, _ ) :: _ -> timestamp

  let newer_than timestamp file =
    let rec aux acc = function
      | [] -> List.rev acc
      | (h, _) :: _ when h <= timestamp -> List.rev acc
      | h::t -> aux (h::acc) t
    in
    aux [] file

  let merge _path ~old t1 t2 =
    let open Irmin.Merge.OP in
    old () >>| fun old ->
    let old = match old with None -> [] | Some o -> o in
    let ts = timestamp old in
    let t1 = newer_than ts t1 in
    let t2 = newer_than ts t2 in
    let t3 = List.sort Entry.compare (List.rev_append t1 t2) in
    ok (List.rev_append t3 old)

  let merge path = Irmin.Merge.option (module Tc.List(Entry)) (merge path)

end

let log_file = [ "local"; "debug" ]

let all_logs t =
  Irmin.read (t "Reading the log file") log_file >>= function
  | None   -> return_nil
  | Some l -> return l

(* Persist a new entry in the log. Pretty inefficient as it
   reads/writes the whole file every time. *)
let log t fmt =
  Printf.ksprintf (fun message ->
      all_logs t >>= fun logs ->
      let logs = Entry.create message :: logs in
      Irmin.update (t "Adding a new entry") log_file logs
    ) fmt

let print_logs name t =
  all_logs t >>= fun logs ->
  Printf.printf "-----------\n%s:\n-----------\n%s%!" name (Log.pretty logs);
  Lwt.return_unit

let main () =
  Config.init ();
  let store = Irmin.basic (module Irmin_git.FS) (module Log) in
  let config = Irmin_git.config ~root:Config.root ~bare:true () in
  Irmin.create store config task >>= fun t ->

  (* populate the log with some random messages *)
  Lwt_list.iter_s (fun msg ->
      log t "This is my %s " msg
    ) [ "first"; "second"; "third"]
  >>= fun () ->

  Printf.printf "%s\n\n" what;

  print_logs "lca" t >>= fun () ->

  Irmin.clone_force task (t "Cloning the store") "test" >>= fun x ->

  log x "Adding new stuff to x"  >>= fun () ->
  log x "Adding more stuff to x" >>= fun () ->
  log x "More. Stuff. To x."     >>= fun () ->

  print_logs "branch 1" x >>= fun () ->

  log t "I can add stuff on t also" >>= fun () ->
  log t "Yes. On t!"                >>= fun () ->

  print_logs "branch 2" t >>= fun () ->

  Irmin.merge_exn "Merging x into t" x ~into:t  >>= fun () ->

  print_logs "merge" t

let () =
  Lwt_unix.run (main ())
