export class AppError extends Error {
  public readonly humanMessage: string
  constructor(
    public readonly code: string,
    public readonly httpStatus: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(`${code}: ${message}`)
    this.name = 'AppError'
    this.humanMessage = message
  }
}

export const Errors = {
  validation: (msg = 'Validation failed', details?: unknown) =>
    new AppError('VALIDATION_ERROR', 400, msg, details),
  malformedQr: () => new AppError('MALFORMED_QR', 400, 'QR payload is malformed'),
  invalidSignature: () => new AppError('INVALID_SIGNATURE', 401, 'QR signature invalid'),
  unauthorized: () => new AppError('UNAUTHORIZED', 401, 'Unauthorized'),
  notFound: (what: string) => new AppError('NOT_FOUND', 404, `${what} not found`),
  nonceUsed: () => new AppError('NONCE_USED', 409, 'QR already consumed'),
  expired: () => new AppError('EXPIRED', 410, 'QR expired'),
  chainTimeout: () => new AppError('CHAIN_TIMEOUT', 503, 'Chain RPC timeout'),
  chainError: (msg = 'Chain RPC error') => new AppError('CHAIN_ERROR', 503, msg),
} as const
