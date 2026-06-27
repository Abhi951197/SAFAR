import { withSupabase } from '@supabase/server';

export default {
  fetch: withSupabase({ auth: 'user' }, async (_req, ctx) => {
    const { data, error } = await ctx.supabase
      .from('diary_entries')
      .select('*')
      .order('entry_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) {
      return Response.json({ message: error.message }, { status: 400 });
    }

    return Response.json(data);
  }),
};
