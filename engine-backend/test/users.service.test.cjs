const test = require('node:test');
const assert = require('node:assert/strict');
const { UsersService } = require('../dist/src/modules/users/users.service');
const { UserRole } = require('../dist/src/common/enums/user-role.enum');

function createService(overrides = {}) {
    const repository = {
        async findAll() { return []; },
        async create(user) { return { id: '1', ...user }; },
        async updateRole(id, role) { },
        async delete(id) { },
        ...overrides,
    };
    return new UsersService(repository);
}

test('UsersService.findAll returns users from repository', async () => {
    const users = [{ id: '1', email: 'test@example.com' }];
    const service = createService({
        async findAll() { return users; }
    });
    const result = await service.findAll();
    assert.deepEqual(result, users);
});

test('UsersService.create calls repository.create', async () => {
    let createdUser = null;
    const service = createService({
        async create(user) {
            createdUser = user;
            return { id: '1', ...user };
        }
    });
    const payload = { email: 'new@example.com', password: 'password123', role: 'ADMIN' };
    await service.create(payload);
    assert.equal(createdUser.email, payload.email);
    assert.equal(createdUser.role, payload.role);
    assert.equal(typeof createdUser.password_hash, 'string');
    assert.ok(createdUser.password_hash.startsWith('scrypt:'));
});

test('UsersService.delete calls repository.delete', async () => {
    let deletedId = null;
    const service = createService({
        async delete(id) {
            deletedId = id;
        }
    });
    await service.delete('123');
    assert.equal(deletedId, '123');
});
