import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Camera, Plus, Wifi, WifiOff } from "lucide-react";

export default function CameraPage() {
  return (
    <div>
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between mb-6">
        <div>
          <h1 className="text-2xl font-heading font-bold tracking-tight">
            Giám sát camera
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            Quản lý và giám sát camera nhận diện biển số
          </p>
        </div>
        <Button className="gap-2">
          <Plus className="h-4 w-4" />
          Thêm camera
        </Button>
      </div>

      {/* Status Overview */}
      <div className="grid gap-4 sm:grid-cols-2 mb-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm text-muted-foreground">
              Online
            </CardTitle>
            <Wifi className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <span className="text-2xl font-bold">0</span>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm text-muted-foreground">
              Offline
            </CardTitle>
            <WifiOff className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <span className="text-2xl font-bold">0</span>
          </CardContent>
        </Card>
      </div>

      <Separator className="mb-6" />

      {/* Empty State */}
      <Card>
        <CardHeader className="text-center">
          <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-lg bg-muted">
            <Camera className="h-6 w-6 text-muted-foreground" />
          </div>
          <CardTitle className="text-lg">Chưa có camera</CardTitle>
          <CardDescription>
            Thêm camera để bắt đầu giám sát và nhận diện biển số tự động.
          </CardDescription>
        </CardHeader>
        <CardContent className="text-center">
          <Badge variant="secondary">Chưa kết nối</Badge>
        </CardContent>
      </Card>
    </div>
  );
}
