package db

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func RunSQLFile(ctx context.Context, pool *pgxpool.Pool, path string) error {
	fmt.Printf("%s Executing %s...\n", time.Now().Format("2006/01/02 15:04:05"), path)

	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	_, err = pool.Exec(ctx, string(b))
	if err != nil {
		return err
	}

	fmt.Printf("%s %s executed successfully\n", time.Now().Format("2006/01/02 15:04:05"), path)
	return nil
}