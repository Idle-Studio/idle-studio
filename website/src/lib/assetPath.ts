export type AssetType = 'eras' | 'wonders' | 'leaders' | 'buildings' | 'root'

export function assetPath(gameId: string, type: AssetType, filename: string): string {
  const dir = type === 'root' ? '' : `${type}/`
  return `/assets/${gameId}/${dir}${filename}.png`
}
