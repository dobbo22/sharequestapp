import handler from '../../../vercel/api/items/[id].js';

export default async function nextApiItemsById(req, res) {
  return handler(req, res);
}
