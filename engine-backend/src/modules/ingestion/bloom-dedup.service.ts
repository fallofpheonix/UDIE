import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';

@Injectable()
export class BloomDedupService {
  private readonly bits = 1 << 22;
  private readonly bytes = this.bits >> 3;
  private readonly hashes = 6;
  private readonly windowMs = 15 * 60_000;
  private current = Buffer.alloc(this.bytes);
  private previous = Buffer.alloc(this.bytes);
  private rotatedAt = Date.now();

  async isProbableDuplicate(key: string, fallbackLookup: () => Promise<boolean>): Promise<boolean> {
    this.rotateIfNeeded();
    if (!this.mightContain(key)) {
      return false;
    }
    return fallbackLookup();
  }

  remember(key: string): void {
    this.rotateIfNeeded();
    for (const index of this.indexesFor(key)) {
      this.setBit(this.current, index);
    }
  }

  private rotateIfNeeded(): void {
    const now = Date.now();
    if (now - this.rotatedAt < this.windowMs) {
      return;
    }
    this.previous = this.current;
    this.current = Buffer.alloc(this.bytes);
    this.rotatedAt = now;
  }

  private mightContain(key: string): boolean {
    for (const index of this.indexesFor(key)) {
      if (!this.getBit(this.current, index) && !this.getBit(this.previous, index)) {
        return false;
      }
    }
    return true;
  }

  private indexesFor(key: string): number[] {
    const digest = createHash('sha256').update(key).digest();
    const indexes: number[] = [];
    for (let i = 0; i < this.hashes; i += 1) {
      const offset = (i * 4) % (digest.length - 3);
      const value = digest.readUInt32BE(offset);
      indexes.push(value % this.bits);
    }
    return indexes;
  }

  private setBit(target: Buffer, index: number): void {
    target[index >> 3] |= 1 << (index & 7);
  }

  private getBit(target: Buffer, index: number): boolean {
    return (target[index >> 3] & (1 << (index & 7))) !== 0;
  }
}
