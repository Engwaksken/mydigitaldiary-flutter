<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Validation\Rule;

class SocialMediaAccountController extends Controller
{
    public function index(Request $request)
    {
        return response()->json([
            'data' => [
                'whatsapp' => [
                    'number' => $request->user()->whatsapp_number,
                    'channel_name' => $request->user()->whatsapp_channel_name,
                    'channel_url' => $request->user()->whatsapp_channel_url,
                ],
                'accounts' => DB::table('social_media_accounts')
                    ->select([
                        'id',
                        'platform',
                        'account_name',
                        'username',
                        'external_account_id',
                        'is_active',
                        'auto_publish_enabled',
                        'oauth_expires_at',
                        DB::raw(
                            "CASE WHEN oauth_access_token IS NULL THEN 0 ELSE 1 END AS is_connected"
                        ),
                    ])
                    ->where('user_id', $request->user()->id)
                    ->orderBy('platform')
                    ->get(),
            ],
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'platform' => [
                'required',
                Rule::in(['instagram','facebook','x','tiktok','linkedin']),
            ],
            'account_name' => ['required','string','max:120'],
            'username' => ['nullable','string','max:180'],
        ]);

        $id = DB::table('social_media_accounts')->insertGetId([
            'user_id' => $request->user()->id,
            'platform' => $data['platform'],
            'account_name' => $data['account_name'],
            'username' => $data['username'] ?? null,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json([
            'data' => DB::table('social_media_accounts')
                ->where('id', $id)
                ->first(),
        ], 201);
    }

    public function updateWhatsApp(Request $request)
    {
        $data = $request->validate([
            'whatsapp_number' => ['nullable','string','max:30'],
            'whatsapp_channel_name' => ['nullable','string','max:180'],
            'whatsapp_channel_url' => ['nullable','url','max:500'],
        ]);

        $request->user()->forceFill($data)->save();

        return response()->json([
            'data' => [
                'number' => $request->user()->whatsapp_number,
                'channel_name' => $request->user()->whatsapp_channel_name,
                'channel_url' => $request->user()->whatsapp_channel_url,
            ],
        ]);
    }


    public function updateAutomaticPublishing(
        Request $request,
        int $account
    ) {
        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
            'external_account_id' => ['nullable', 'string', 'max:255'],
            'access_token' => ['nullable', 'string', 'max:10000'],
        ]);

        $row = DB::table('social_media_accounts')
            ->where('id', $account)
            ->where('user_id', $request->user()->id)
            ->first();

        abort_unless($row, 404);

        $update = [
            'auto_publish_enabled' => (bool) $data['enabled'],
            'updated_at' => now(),
        ];

        if (array_key_exists('external_account_id', $data)) {
            $update['external_account_id'] =
                trim((string) $data['external_account_id']) ?: null;
        }

        if (! empty($data['access_token'])) {
            $update['oauth_access_token'] = Crypt::encryptString(
                $data['access_token']
            );
        }

        DB::table('social_media_accounts')
            ->where('id', $account)
            ->where('user_id', $request->user()->id)
            ->update($update);

        return response()->json([
            'data' => DB::table('social_media_accounts')
                ->select([
                    'id',
                    'platform',
                    'account_name',
                    'username',
                    'external_account_id',
                    'is_active',
                    'auto_publish_enabled',
                    'oauth_expires_at',
                    DB::raw(
                        "CASE WHEN oauth_access_token IS NULL THEN 0 ELSE 1 END AS is_connected"
                    ),
                ])
                ->where('id', $account)
                ->where('user_id', $request->user()->id)
                ->first(),
        ]);
    }

    public function destroy(Request $request, int $account)
    {
        DB::table('social_media_accounts')
            ->where('id', $account)
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json(['ok' => true]);
    }
}
