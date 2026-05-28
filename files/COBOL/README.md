# files — COBOL

GnuCOBOL bridge to the [C file client](../C/README.md).

## Build

```shell
cd files/COBOL
make
```

## Entry points

| Entry | Description |
|-------|-------------|
| `FILELOCALREAD` | Read local file |
| `FILELOCALWRITE` | Write local file |
| `FILELOCALMOVE` | Move/rename local file |

Set `COB_LIBRARY_PATH=.` when running compiled programs.

Apache License 2.0.
