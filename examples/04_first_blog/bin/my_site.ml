open Yocaml

let destination = "_build"
let css_destination = into destination "css"
let images_destination = into destination "images"
let track_binary_update = Build.watch Sys.argv.(0)

let may_process_markdown file =
  let open Build in
  if with_extension "md" file then snd process_markdown else arrow Fun.id
;;

let pages =
  process_files
    [ "pages/" ]
    (fun f -> with_extension "html" f || with_extension "md" f)
    (fun file ->
      let fname = basename file |> into destination in
      let target = replace_extension fname "html" in
      let open Build in
      create_file
        target
        (track_binary_update
        >>> read_file_with_metadata (module Metadata.Page) file
        >>> may_process_markdown file
        >>> apply_as_template (module Metadata.Page) "templates/layout.html"
        >>^ Stdlib.snd))
;;

let article_destination file =
  let fname = basename file |> into "articles" in
  replace_extension fname "html"
;;

let articles =
  process_files [ "articles/" ] (with_extension "md") (fun file ->
      let open Build in
      let target = article_destination file |> into destination in
      create_file
        target
        (track_binary_update
        >>> read_file_with_metadata (module Metadata.Article) file
        >>> snd process_markdown
        >>> apply_as_template
              (module Metadata.Article)
              "templates/article.html"
        >>> apply_as_template
              (module Metadata.Article)
              "templates/layout.html"
        >>^ Stdlib.snd))
;;

let css =
  process_files [ "css/" ] (with_extension "css") (fun file ->
      Build.copy_file file ~into:css_destination)
;;

let images =
  let open Preface.Predicate in
  process_files
    [ "images" ]
    (with_extension "svg" || with_extension "png" || with_extension "gif")
    (fun file -> Build.copy_file file ~into:images_destination)
;;

let index =
  let open Build in
  let* articles =
    collection
      (read_child_files "articles/" (with_extension "md"))
      (fun source ->
        track_binary_update
        >>> read_file_with_metadata (module Metadata.Article) source
        >>^ fun (x, _) -> x, article_destination source)
      (fun x meta content ->
        x
        |> Metadata.Articles.make
             ?title:(Metadata.Page.title meta)
             ?description:(Metadata.Page.description meta)
        |> Metadata.Articles.sort_articles_by_date
        |> fun x -> x, content)
  in
  create_file
    (into destination "index.html")
    (track_binary_update
    >>> read_file_with_metadata (module Metadata.Page) "index.md"
    >>> snd process_markdown
    >>> articles
    >>> apply_as_template (module Metadata.Articles) "templates/list.html"
    >>> apply_as_template (module Metadata.Articles) "templates/layout.html"
    >>^ Stdlib.snd)
;;

let () = Yocaml_unix.execute (pages >> css >> images >> articles >> index)
