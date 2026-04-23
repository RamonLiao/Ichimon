import type { SuiService } from './sui.js'

export type MomentChainState = {
  status: 0 | 1 | 2
  total_guardians: number
  total_points: number
  preservation_until: number
  top_guardians: Array<{ fan_sbt_id: string; rank: number; tier: 0 | 1 | 2 | 3; points_contributed: number }>
}

export async function readMomentState(sui: SuiService, momentId: string): Promise<MomentChainState> {
  // POST-MVP FILL-IN: when a real moment is proposed on testnet, expand with
  // listDynamicFields (paginated, limit 50) -> batchGetObjects -> BCS decode of
  // GuardianEntry -> sort by rank, slice top 10, compute tier
  // (<=3 gold/1, <=10 silver/2, <=30 bronze/3). Spec sec 4.2.1.
  return sui.getObjectCached<MomentChainState>(momentId, 10, (raw: unknown) => {
    const r = raw as any
    const c = r?.object?.contents?.value
      ?? r?.object?.contents
      ?? r?.contents?.value
      ?? r?.contents
      ?? r?.data?.content?.fields
      ?? {}
    return {
      status: (Number(c.status ?? 0) as 0 | 1 | 2),
      total_guardians: Number(c.total_guardians ?? 0),
      total_points: Number(c.total_points ?? 0),
      preservation_until: Number(c.preservation_until ?? 0),
      top_guardians: [],
    }
  })
}

export function emptyMomentState(): MomentChainState {
  return { status: 0, total_guardians: 0, total_points: 0, preservation_until: 0, top_guardians: [] }
}
