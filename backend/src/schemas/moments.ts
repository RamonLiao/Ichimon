import { Type } from '@sinclair/typebox'

export const MomentStatusQuery = Type.Object({
  status: Type.Optional(Type.Union([
    Type.Literal('candidate'),
    Type.Literal('finalized'),
    Type.Literal('expired'),
  ])),
})

export const TopGuardian = Type.Object({
  fan_sbt_id: Type.String(),
  rank: Type.Number(),
  tier: Type.Union([Type.Literal(0), Type.Literal(1), Type.Literal(2), Type.Literal(3)]),
  points_contributed: Type.Number(),
})

export const Moment = Type.Object({
  moment_id: Type.String(),
  title: Type.String(),
  description: Type.String(),
  video_url: Type.String(),
  thumbnail_url: Type.String(),
  status: Type.Union([Type.Literal(0), Type.Literal(1), Type.Literal(2)]),
  total_guardians: Type.Number(),
  total_points: Type.Number(),
  preservation_until: Type.Number(),
  top_guardians: Type.Array(TopGuardian),
})

export const MomentsResponse = Type.Object({ moments: Type.Array(Moment) })
