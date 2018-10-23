# Orbit - A MetaWeblog API Server for Hugo

![](https://github.com/elliotekj/orbit/blob/master/.README/demo.gif)

Orbit is a MetaWeblog API server for blogs powered by
[Hugo](https://gohugo.io). It was written so that I could write and publish to
my [blog](https://elliotekj.com) from
[MarsEdit](https://www.red-sweater.com/marsedit/). It supports draft posts (not
a MetaWeblog standard) and MarsEdit's drag & drop image insertion. It also has
built-in token verification so you can safely expose it on your server.

**Jump to:** [Basic Usage](https://github.com/elliotekj/orbit#basic-usage) | [Post Types](https://github.com/elliotekj/orbit#post-types) | [Update Command](https://github.com/elliotekj/orbit#update-command) | [Authentication](https://github.com/elliotekj/orbit#authentication) | [Draft Posts](https://github.com/elliotekj/orbit#draft-posts)| [All Options](https://github.com/elliotekj/orbit#all-options)


## Basic Usage

1. [Download Orbit](https://github.com/elliotekj/orbit/archive/master.zip)

2. `cd` into the folder and run:

```sh
$ ruby app/orbit.rb -s /YOUR/HUGO/SITE/PATH
```

3. Configure MarsEdit:

![MarsEdit configuration](https://github.com/elliotekj/orbit/blob/master/.README/marsedit.png)


## Post Types

If your blog, like mine, has multiple post types (e.g. link posts, regular
posts, and microposts), you can still use Orbit. When starting Orbit, the `-c`
flag allows you to you can specify the folder within `content` the post will be
saved in.

Example: The following will save posts sent to port 4041 in the `link` folder.

```sh
$ ruby app/orbit.rb -s /YOUR/HUGO/SITE/PATH -c link -p 4041
```

## Update Command

If you don't want to have `hugo server` constantly running to watch for changes
(for example if you're running Orbit on your server), you can regenerate your
site with a command passed to the `-u` flag.

Example:

```sh
$ ruby app/orbit.rb -s /YOUR/HUGO/SITE/PATH -u "cd /YOUR/HUGO/SITE/PATH && hugo"
```

Tip for [Micro.Blog](https://micro.blog) users: You can use the `-u` flag to ping Micro.Blog whenever you publish a new micropost

```sh
$ ruby app/orbit.rb -s /YOUR/HUGO/SITE/PATH -u "curl -d 'url=https://YOURSITE.com/microposts.json' -X POST http://micro.blog/ping"
```

## Authentication

If you want to expose Orbit on your server (which is how I use Orbit), you'll
want to take advantage of the built-in token verification. When starting Orbit,
pass some secret token to the `-t` flag and update the `API Endpoint URL` in
MarsEdit with a `token` parameter.

Example:

```sh
$ ruby app/orbit.rb -s /YOUR/HUGO/SITE/PATH -t MYSECRETTOKEN
```

Then in MarsEdit, if your endpoint was, for example,
`https://hugo.elliotekj.com/xmlrpc` you'd update it to
`https://hugo.elliotekj.com/xmlrpc?token=MYSECRETTOKEN`.

## Draft Posts

Draft posts aren't a MetaWeblog standard. Orbit works around this by adding
a `[Orbit - Draft]` category to the category list. If you use that category
then when saving your post, `draft` will be set to true in the post's
frontmatter.

## All Options

- `-s PATH` `--src-path PATH`: Path to your Hugo site (required)
- `-c FOLDER_NAME` `--content-folder FOLDER_NAME`: Name of the folder in `/content` you want Orbit to serve (default: 'post')
- `-p PORT` `--port PORT`: Port to run Orbit on (default: 4040)
- `-t TOKEN` `--token TOKEN`: Token used for authenticating yourself (optional)
- `-u COMMAND` `--update-command COMMAND`: Command run when your site is updated (optional)

## Common Issues
### MarsEdit won't load any of my old posts

Check that your front matter (the metadata block above each of your raw posts) is in YAML form. If you're not sure which format that is, check the separator between the metadata block, and your actual post. It could be `+++`, `---`, or enclosed in `{` and `}`. 

If it is not the form ending with three dashes, (`---`), you'll need to convert your old posts before continuing. Hugo provides a built-in tool for this: `hugo convert toYAML`

## License

Orbit is released under the MIT [`LICENSE`](https://github.com/elliotekj/orbit/blob/master/LICENSE).

## About

This crate was written by [Elliot Jackson](https://elliotekj.com).

- Blog: [https://elliotekj.com](https://elliotekj.com)
- Email: elliot@elliotekj.com
