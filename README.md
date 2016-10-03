# pbgrab-cli

pbgrab-cli is an adaptation of [Arjun Roychowdhury](http://www.roychowdhury.org)'s [pb2smug](http://www.roychowdhury.org/software) script. That software is a "combined PBase gallery downloader and uploader to Smugmug".

I have taken the core code of his software and written a very simple command-line-interfice (CLI) around it. This means that for linux and MacOS users, you can likely run this from the commandline to download photos and metadata from a [pbase](www.pbase.com) gallery.

## Usage

```
./PBGrab-cli.pl -u <username> -gallery <galleryname> -root <rootpath> -d
```

Prompts for the `password` associated with `username`. Logs into [pbase](www.pbase.com) and downloads (recursively) the gallery specified by `galleryname`.

Will save the output into a set of directories under `rootpath/galleryname`. (Note: In fact, it currently saves it into `/private/rootpath/galleryname`, and I've not yet determined why.)

The files and directories it creates are as follows:

| File/Directory | Content |
|:---------------|:--------|
| captions | The captions of each image (where the gallery is a photoblog).|
| dates | The dates of each image (where these can be determined).|
| gallerydesc.txt | The gallery description. |
| images | The original images (or the largest size available).|
| index.html | An auto-generated page of thumbnails with links to the full-size images |
| thumbs | Thumbnails (generated by the script). |
| titles | Titles for each image.|

All files are numbered from `0` to `n-1` where `n` is the number of images in the gallery. In `images`, these will be `0.jpg`, `1.jpg`, `2.jpg` ... In `thumbs` these will be `thumb_0.jpg`,  `thumb_1.jpg`,  `thumb_2.jpg`, ...

In `captions` and `titles` the files are `0.txt`, `1.txt`, `2.txt` ... Note that the `striphtml` command-line option does not work reliably.

## Disclaimers

This software has **not** been extensively tested or debugged. Some of the commandline options which it advertises do not work as they are supposed to. **YOU USE THIS ENTIRELY AT YOUR OWN RISK.**

It works well enough for me. I have debugged some of the ongoing problems. I have used it to back up my data from pbase but am about to close my pbase account so will not need it nor be able to debug it any more.

## Why would you want to use this? 

[Arjun Roychowdhury](http://www.roychowdhury.org) has done much of the difficult work of figuring out how to extract gallery data from [pbase](www.pbase.com). Even if you have to adapt or debug this code to make it do what you want it to do, this is already a step up from finding the code within the Windows `zip` file and getting it going on the command-line from scratch.

This script will predictably get your photos and descriptions down into a simple, usable format. I used it, along with other tools, to rebuid personal photo galleries using [jekyll](http://jekyllrb.com).

## License

 ![Creative Commons License](http://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png)  
This work, as a derivative work of Arjun Roychowdhury's work, is licensed under a [Creative Commons Attribution-Noncommercial-Share Alike 3.0 Unported License](http://creativecommons.org/licenses/by-nc-sa/3.0/)

Modifications are by [Richard Martin-Nielsen](https://github.com/RichardMN) in August-October 2016.
