import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool, QueryResultRow } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleDestroy {
  private readonly pool: Pool;
  private readonly replicaPool: Pool | null = null;

  constructor() {
    this.pool = new Pool({ connectionString: process.env.DATABASE_URL });
    if (process.env.REPLICA_URL) {
      this.replicaPool = new Pool({ connectionString: process.env.REPLICA_URL });
    }
  }

  /**
   * Primary query method (Master/Write) with retry logic for connection stability
   */
  async query<T extends QueryResultRow>(text: string, params: unknown[] = [], retries = 5) {
    for (let i = 0; i < retries; i++) {
      try {
        return await this.pool.query<T>(text, params);
      } catch (err: any) {
        if (err.code === 'ECONNREFUSED' && i < retries - 1) {
          const delay = Math.pow(2, i) * 1000;
          console.warn(`[DB] Connection refused. Retrying in ${delay}ms... (${i + 1}/${retries})`);
          await new Promise(resolve => setTimeout(resolve, delay));
          continue;
        }
        throw err;
      }
    }
    return this.pool.query<T>(text, params); // Fallback to standard call
  }

  /**
   * Read-only query method (Replica/Read)
   */
  queryRead<T extends QueryResultRow>(text: string, params: unknown[] = []) {
    const targetPool = this.replicaPool || this.pool;
    return targetPool.query<T>(text, params);
  }

  getPool() {
    return this.pool;
  }

  async healthCheck() {
    await this.queryRead('SELECT 1');
  }

  async onModuleDestroy() {
    await this.pool.end();
    if (this.replicaPool) {
      await this.replicaPool.end();
    }
  }
}
