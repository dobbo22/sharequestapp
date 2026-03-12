#!/usr/bin/env node
import { argv } from 'process';

// Simple integration test that expects a running vercel dev at localhost:3000
const host = argv[2] || 'http://localhost:3000';
const token = process.env.TEST_API_TOKEN || '';

async function run() {
  console.log('Running integration test against', host);

  // GET items
  let res = await fetch(`${host}/api/items`);
  console.log('GET /api/items', res.status);
  const items = await res.json().catch(()=>null);
  console.log('items count:', Array.isArray(items)?items.length:'n/a');

  if (!token) {
    console.warn('TEST_API_TOKEN not set; skipping authenticated tests. Set env var TEST_API_TOKEN to run full tests.');
    process.exit(0);
  }

  // Create item
  res = await fetch(`${host}/api/items`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({ title: 'Integration Test Item', details: 'created by integration test', priority: 2 })
  });
  console.log('POST /api/items', res.status);
  const created = await res.json();
  console.log('created:', created);

  if (!created || !created.id) {
    console.error('Create failed');
    process.exit(1);
  }

  const id = created.id;

  // Update item
  res = await fetch(`${host}/api/items/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({ title: 'Integration Test Item - updated' })
  });
  console.log('PUT /api/items/:id', res.status);

  // Delete
  res = await fetch(`${host}/api/items/${id}`, {
    method: 'DELETE',
    headers: { 'Authorization': `Bearer ${token}` }
  });
  console.log('DELETE /api/items/:id', res.status);

  console.log('Integration test completed');
}

run().catch(err=>{ console.error(err); process.exit(1) });
