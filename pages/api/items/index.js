import handler from '../../../vercel/api/items/index.js';

export default async function nextApiItemsIndex(req, res) {
  return handler(req, res);
}
