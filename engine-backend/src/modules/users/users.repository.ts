import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { UserEntity } from './entities/user.entity';

@Injectable()
export class UsersRepository {
    constructor(private readonly databaseService: DatabaseService) { }

    async findAll(): Promise<UserEntity[]> {
        const res = await this.databaseService.query<UserEntity>(
            'SELECT id, email, password_hash, role, full_name, created_at, updated_at FROM users ORDER BY created_at DESC',
        );
        return res.rows;
    }

    async findByEmail(email: string): Promise<UserEntity | null> {
        const res = await this.databaseService.query<UserEntity>(
            'SELECT id, email, password_hash, role, full_name, created_at, updated_at FROM users WHERE email = $1',
            [email],
        );
        return res.rows[0] || null;
    }

    async findById(id: string): Promise<UserEntity | null> {
        const res = await this.databaseService.query<UserEntity>(
            'SELECT id, email, password_hash, role, full_name, created_at, updated_at FROM users WHERE id = $1',
            [id],
        );
        return res.rows[0] || null;
    }

    async create(user: Partial<UserEntity>): Promise<UserEntity> {
        const res = await this.databaseService.query<UserEntity>(
            'INSERT INTO users (email, password_hash, role, full_name) VALUES ($1, $2, $3, $4) RETURNING id, email, password_hash, role, full_name, created_at, updated_at',
            [user.email, user.password_hash, user.role, user.full_name],
        );
        return res.rows[0];
    }

    async updateRole(id: string, role: string): Promise<void> {
        await this.databaseService.query(
            'UPDATE users SET role = $1, updated_at = now() WHERE id = $2',
            [role, id],
        );
    }

    async delete(id: string): Promise<void> {
        await this.databaseService.query('DELETE FROM users WHERE id = $1', [id]);
    }
}
