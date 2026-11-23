// Command caizen runs the Caizen service and its maintenance commands.
//
//	caizen serve    run the long-lived service
//	caizen ingest   run one ingest pass against a raw root, then exit
//
// Every flag falls back to a CAIZEN_* environment variable.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/caizencloud/caizen/app/internal/db"
	"github.com/caizencloud/caizen/app/internal/ingest"
	"github.com/caizencloud/caizen/app/internal/pack"
)

const usage = `usage: caizen <command> [flags]

commands:
  serve    run the long-lived service
  ingest   run one ingest pass against a raw root, then exit

Run "caizen <command> -h" for the command's flags.
`

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stderr, nil)))

	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	var err error
	switch os.Args[1] {
	case "serve":
		err = serve(ctx, os.Args[2:])
	case "ingest":
		err = runIngest(ctx, os.Args[2:])
	case "-h", "-help", "--help", "help":
		fmt.Print(usage)
		return
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n%s", os.Args[1], usage)
		os.Exit(2)
	}
	if err != nil {
		slog.Error(os.Args[1]+" failed", "err", err)
		os.Exit(1)
	}
}

// config holds the settings shared by serve and ingest.
type config struct {
	raw   string
	packs string
	db    string
}

func (c *config) flags(fs *flag.FlagSet) {
	fs.StringVar(&c.raw, "raw", os.Getenv("CAIZEN_RAW"),
		"raw root: gs://<bucket>/raw or a local directory (CAIZEN_RAW)")
	fs.StringVar(&c.packs, "packs", os.Getenv("CAIZEN_PACKS"),
		"pack root: gs://<bucket>/packs/<digest> or a local directory (CAIZEN_PACKS)")
	fs.StringVar(&c.db, "db", os.Getenv("CAIZEN_DB"),
		"DuckDB file (CAIZEN_DB)")
}

func (c *config) check() error {
	var missing []string
	for _, f := range []struct{ name, value string }{{"raw", c.raw}, {"packs", c.packs}, {"db", c.db}} {
		if f.value == "" {
			missing = append(missing, "-"+f.name)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("missing %s", strings.Join(missing, ", "))
	}
	return nil
}

// remote reports whether any root is a gs:// URI.
func (c *config) remote() bool {
	return strings.HasPrefix(c.raw, "gs://") || strings.HasPrefix(c.packs, "gs://")
}

func (c *config) open(ctx context.Context) (*db.DB, error) {
	d, err := db.Open(ctx, db.Options{Path: c.db, Remote: c.remote()})
	if err != nil {
		return nil, err
	}
	slog.Info("database open", "path", c.db, "fresh", d.Fresh, "schema_version", db.SchemaVersion)
	return d, nil
}

func runIngest(ctx context.Context, args []string) error {
	var c config
	var opts ingest.Options
	fs := flag.NewFlagSet("ingest", flag.ExitOnError)
	c.flags(fs)
	fs.BoolVar(&opts.Reconcile, "reconcile", false, "list every feed's whole history, not only the last 7 days")
	fs.Func("accept", "release a quarantined batch ID, such as gcp-cai-resource/ingest_dt=2026-11-19/run=20261119T060000Z (repeatable)",
		func(s string) error { opts.Accept = append(opts.Accept, s); return nil })
	fs.Parse(args)
	if err := c.check(); err != nil {
		return err
	}
	d, err := c.open(ctx)
	if err != nil {
		return err
	}
	defer d.Close()

	packs, err := pack.Load(ctx, d.DB, c.packs)
	if err != nil {
		return err
	}
	for _, p := range packs {
		slog.Info("pack loaded", "id", p.ID, "version", p.Version)
	}

	opts.Raw = c.raw
	rep, err := ingest.Run(ctx, d.DB, opts)
	if err != nil {
		return err
	}
	for _, r := range rep.Batches {
		slog.Info("batch", "feed", r.Feed, "batch", r.Batch, "status", r.Status,
			"records", r.Records, "rejects", r.Rejects, "reason", r.Reason)
	}
	for _, s := range rep.Skipped {
		slog.Warn("feed skipped until the next pass", "feed", s.Feed, "err", s.Err)
	}
	slog.Info("ingest done", "batches", len(rep.Batches), "skipped_feeds", len(rep.Skipped))
	if len(rep.Skipped) > 0 {
		return fmt.Errorf("%d feeds skipped", len(rep.Skipped))
	}
	return nil
}

func serve(ctx context.Context, args []string) error {
	return errors.New("serve is part of milestone 2 and is not built yet")
}
